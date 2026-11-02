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
import '../models/rate_schedule_model.dart';
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

  /// Records a payment for the first unpaid period of a sale.
  Future<void> recordPayment({
    required String saleId,
    required String payer,
    required String paidBy,
    required PaymentMethod method,
  }) async {
    final snap = await _payments
        .where('saleId', isEqualTo: saleId)
        .get();

    final docs = snap.docs.toList();
    docs.sort((a, b) {
      final pa = (a.data()['period'] as num?)?.toInt() ?? 0;
      final pb = (b.data()['period'] as num?)?.toInt() ?? 0;
      return pa.compareTo(pb);
    });

    for (final doc in docs) {
      final p = LotPaymentModel.fromMap(doc.data());
      if (p.status != LotPaymentStatus.paid) {
        await _payments.doc(doc.id).update({
          'status': LotPaymentStatus.paid.name,
          'paidAt': Timestamp.now(),
          'paidBy': paidBy,
          'payer': payer,
          'paymentMethod': method.name,
          'verifiedAt': method == PaymentMethod.cash ? Timestamp.now() : null,
        });
        await _checkIfPaidOff(saleId);
        return;
      }
    }
    throw Exception('No unpaid periods for this sale.');
  }

  Future<void> _checkIfPaidOff(String saleId) async {
    final snap = await _payments.where('saleId', isEqualTo: saleId).get();
    bool allPaid = true;
    for (final doc in snap.docs) {
      final p = LotPaymentModel.fromMap(doc.data());
      if (p.status != LotPaymentStatus.paid) {
        allPaid = false;
        break;
      }
    }
    if (allPaid) {
      await _sales.doc(saleId).update({
        'status': LotSaleStatus.paidOff.name,
        'paidOffAt': Timestamp.now(),
      });
    }
  }

  Future<void> closeoutSale({
    required String saleId,
    required double refundAmount,
    required String closedBy,
  }) async {
    final snap = await _payments
        .where('saleId', isEqualTo: saleId)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      final p = LotPaymentModel.fromMap(doc.data());
      if (p.status == LotPaymentStatus.scheduled) {
        batch.update(doc.reference, {'status': LotPaymentStatus.void_.name});
      }
    }

    batch.update(_sales.doc(saleId), {
      'status': LotSaleStatus.cancelled.name,
      'refundAmount': refundAmount,
      'closedBy': closedBy,
      'closedAt': Timestamp.now(),
    });

    await batch.commit();
  }

  Future<void> transferLot({
    required String saleId,
    required String newBuyerUid,
    required String newBuyerName,
    required String updatedBy,
  }) async {
    final saleDoc = await _sales.doc(saleId).get();
    if (!saleDoc.exists) throw Exception('Sale not found.');

    final sale = LotSaleModel.fromMap(saleDoc.data()!, saleDoc.id);

    // Update lot ownership
    await _db.collection('lots').doc(sale.lotId).update({
      'uid': newBuyerUid,
      'ownerName': newBuyerName,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });

    // Update sale record
    await _sales.doc(saleId).update({
      'buyerUid': newBuyerUid,
      'buyerName': newBuyerName,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<List<Map<String, dynamic>>> getPaymentsReportDataset() async {
    final paymentsSnap = await _payments.get();
    final salesSnap = await _sales.get();

    final sales = {
      for (final doc in salesSnap.docs)
        doc.id: LotSaleModel.fromMap(doc.data(), doc.id)
    };

    return paymentsSnap.docs.map((doc) {
      final p = LotPaymentModel.fromMap(doc.data());
      final s = sales[p.saleId];
      return {
        'period': p.period,
        'amount': p.amount,
        'status': p.status.name,
        'buyerName': s?.buyerName ?? 'Unknown',
        'lotNumber': s?.lotNumber ?? 'Unknown',
        'soldDate': s?.soldDate,
      };
    }).toList();
  }

  Stream<List<LotSaleModel>> streamSalesForLot(String lotId) {
    return _sales
        .where('lotId', isEqualTo: lotId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotSaleModel.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<LotPaymentModel>> streamPaymentsForSale(String saleId) {
    return _payments
        .where('saleId', isEqualTo: saleId)
        .orderBy('period')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotPaymentModel.fromMap(d.data()))
            .toList());
  }

  Future<LotSaleModel?> getSale(String saleId) async {
    final doc = await _sales.doc(saleId).get();
    if (!doc.exists) return null;
    return LotSaleModel.fromMap(doc.data()!, doc.id);
  }

  Stream<List<LotSaleModel>> streamAllSales() {
    return _sales.snapshots().map((snap) => snap.docs
        .map((d) => LotSaleModel.fromMap(d.data(), d.id))
        .toList());
  }

  Future<List<LotSaleModel>> getAllSalesForLot(String lotId) async {
    final snap = await _sales.where('lotId', isEqualTo: lotId).get();
    return snap.docs
        .map((d) => LotSaleModel.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> recalculateActiveSales(RateScheduleModel schedule, {required double saleArea}) async {
    final activeSalesSnap = await _sales.where('status', isEqualTo: 'active').get();
    final batch = _db.batch();

    for (final doc in activeSalesSnap.docs) {
      final sale = LotSaleModel.fromMap(doc.data(), doc.id);

      final sortedTiers = List<RateTier>.from(schedule.tiers)
        ..sort((a, b) => b.threshold.compareTo(a.threshold));

      final tier = sortedTiers.firstWhere(
        (t) => saleArea >= t.threshold,
        orElse: () => sortedTiers.last,
      );

      final newTotalPrice = saleArea * tier.rate;
      final newFinancedAmount = newTotalPrice - sale.downPayment;

      final newMonthlyPayment = AmortizationService.monthlyPayment(
        newFinancedAmount,
        sale.annualInterestRate,
        sale.termMonths
      );

      batch.update(doc.reference, {
        'totalPrice': newTotalPrice,
        'financedAmount': newFinancedAmount,
        'monthlyPayment': newMonthlyPayment,
        'updatedAt': Timestamp.now(),
      });

      final paymentsSnap = await _payments
          .where('saleId', isEqualTo: sale.id)
          .where('status', isEqualTo: 'scheduled')
          .get();
      for (final pDoc in paymentsSnap.docs) {
        batch.delete(pDoc.reference);
      }

      final newSchedule = AmortizationService.buildSchedule(
        sale: sale.copyWith(
          totalPrice: newTotalPrice,
          financedAmount: newFinancedAmount,
          monthlyPayment: newMonthlyPayment
        ),
        firstDueDate: sale.soldDate,
        createdBy: 'admin',
      );

      for (final p in newSchedule) {
        batch.set(_payments.doc(), p.toMap());
      }
    }
    await batch.commit();
  }
}
