// core/services/sale_service.dart
//
// Handles Firestore writes for lot sales and payment schedules.
//
// Collections:
//   `lot_sales`  — one document per sale (cash or installment)
//   `lot_payments` — one document per payment period
//
// `recordSale` is the single entry point: it writes the sale doc, the
// payment schedule, and links the lot to the buyer in one batch so the
// three collections always stay in sync.

import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, FirebaseFirestore, SetOptions, Timestamp;
import '../models/lot_model.dart';
import '../models/lot_sale_model.dart';
import '../models/lot_payment_model.dart';
import 'amortization_service.dart';

class SaleService {
  final FirebaseFirestore _db;

  SaleService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('lot_sales');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('lot_payments');

  /// Records a sale for [lot] to [buyerUid] / [buyerName].
  ///
  /// Cash (`termMonths == 0`): one payment doc marked `paid`, sale status
  /// `paidOff`, lot status `occupied`.
  ///
  /// Installment (`termMonths > 0`): sale status `active`, N payment docs
  /// with `scheduled` status (period 0 down payment marked `paid` when
  /// `downPayment > 0`), lot status `occupied`.
  Future<void> recordSale({
    required LotModel lot,
    required String buyerUid,
    required String buyerName,
    required double downPayment,
    required int termMonths,
    required double annualInterestRate,
    required DateTime soldDate,
    required String recordedBy,
  }) async {
    final totalPrice = lot.price ?? 0.0;
    final financedAmount = totalPrice - downPayment;
    final monthlyPayment = termMonths > 0
        ? AmortizationService.monthlyPayment(
            financedAmount, annualInterestRate, termMonths)
        : 0.0;

    final saleSeq = await _nextSaleSeq(soldDate.year);
    final saleId = _sales.doc().id;

    final sale = LotSaleModel(
      id: saleId,
      lotId: lot.id,
      lotNumber: lot.lotNumber,
      phase: lot.phase,
      block: lot.block,
      buyerUid: buyerUid,
      buyerName: buyerName,
      saleType: termMonths == 0 ? SaleType.cash : SaleType.installment,
      totalPrice: totalPrice,
      downPayment: downPayment,
      financedAmount: financedAmount,
      termMonths: termMonths,
      annualInterestRate: annualInterestRate,
      monthlyPayment: monthlyPayment,
      status: termMonths == 0 ? LotSaleStatus.paidOff : LotSaleStatus.active,
      soldDate: soldDate,
      saleSeq: saleSeq,
      createdBy: recordedBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final schedule = AmortizationService.buildSchedule(
      sale: sale,
      firstDueDate: soldDate,
      createdBy: recordedBy,
      saleSeq: saleSeq,
    );

    final batch = _db.batch();
    batch.set(_sales.doc(saleId), sale.toMap());

    for (final p in schedule) {
      final isCash = termMonths == 0;
      final isDown = p.period == 0 && downPayment > 0;
      batch.set(
        _payments.doc(),
        p.copyWith(
          status: (isCash || isDown) ? LotPaymentStatus.paid : LotPaymentStatus.scheduled,
          paidAt: (isCash || isDown) ? DateTime.now() : null,
          paidBy: (isCash || isDown) ? recordedBy : null,
        ).toMap(),
      );
    }

    batch.set(
      _db.collection('lots').doc(lot.id),
      {
        'uid': buyerUid,
        'ownerName': buyerName,
        'status': LotStatus.occupied.name,
        'updatedAt': Timestamp.now(),
        'updatedBy': recordedBy,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Next per-year sale sequence number (1-based), so transaction IDs
  /// never collide across sales in the same year.
  Future<int> _nextSaleSeq(int year) async {
    final snap = await _sales
        .where('soldDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(year, 1, 1)))
        .where('soldDate', isLessThan: Timestamp.fromDate(DateTime(year + 1, 1, 1)))
        .get();
    if (snap.docs.isEmpty) return 1;
    var max = 0;
    for (final d in snap.docs) {
      final seq = (d.data()['saleSeq'] as num?)?.toInt() ?? 0;
      if (seq > max) max = seq;
    }
    return max + 1;
  }

  /// Streams all sales for a given lot.
  Stream<List<LotSaleModel>> streamSalesForLot(String lotId) {
    return _sales
        .where('lotId', isEqualTo: lotId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotSaleModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Streams all payment records for a given sale.
  Stream<List<LotPaymentModel>> streamPaymentsForSale(String saleId) {
    return _payments
        .where('saleId', isEqualTo: saleId)
        .orderBy('period')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotPaymentModel.fromMap(d.data()))
            .toList());
  }

  /// Reads a single sale by id.
  Future<LotSaleModel?> getSale(String saleId) async {
    final doc = await _sales.doc(saleId).get();
    if (!doc.exists) return null;
    return LotSaleModel.fromMap(doc.data()!, doc.id);
  }
}