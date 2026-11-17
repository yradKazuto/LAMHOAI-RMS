import 'package:cloud_firestore/cloud_firestore.dart'
    show
        CollectionReference,
        DocumentReference,
        FirebaseFirestore,
        SetOptions,
        Timestamp;

import '../models/lot_model.dart';
import '../models/lot_sale_model.dart';
import '../models/lot_payment_model.dart';
import '../models/lot_ownership_model.dart';
import '../models/payment_model.dart';
import '../utils/lot_pricing.dart';
import 'amortization_service.dart';
import 'rate_service.dart';

class LotNotAvailableException implements Exception {
  final String lotId;

  const LotNotAvailableException(this.lotId);

  @override
  String toString() => 'Lot $lotId is no longer available.';
}

class SaleService {
  final FirebaseFirestore _db;

  SaleService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('lot_sales');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('lot_payments');

  /// One row per ownership period of a lot (current owner has endedAt == null).
  CollectionReference<Map<String, dynamic>> get _ownerHistory =>
      _db.collection('lot_ownership_history');

  // ── Mirror into the main `payments` collection ──────────────────────────
  // The Payments screen, its summary cards, the member payment records and the
  // Reports all read the `payments` collection. Lot down payments and
  // installment periods live in `lot_payments`, so we keep a matching
  // `payments` record (type lotPayment) for them.
  //
  // • The cash purchase / down payment record is created at registration as
  //   PENDING (unpaid). It becomes PAID only when someone marks it paid after
  //   the money is received.
  // • Installment periods get their record when they are paid.
  //
  // The mirror's document id is deterministic (lot_<saleId>_<period>), so the
  // same period can never be mirrored twice — marking a pending record paid
  // updates that same document.
  CollectionReference<Map<String, dynamic>> get _mainPayments =>
      _db.collection('payments');

  static const String _mirrorSource = 'lot_payment';

  /// Document id of the `payments` mirror for a lot payment row.
  /// Deterministic, so the same period can never be mirrored twice. EVERY
  /// writer of `payments/lot_*` docs must use this — FirestoreService
  /// included — or "Mark Paid" can't parse the id back into saleId+period.
  static String mirrorId(String saleId, int period) => 'lot_${saleId}_$period';

  /// Readable reference, e.g. LP-2026-0001-DP (down payment) or
  /// LP-2026-0001-P003 (period 3) — year + sale sequence + period.
  String _mirrorTxnId(LotSaleModel sale, LotPaymentModel p) {
    final seq = sale.saleSeq.toString().padLeft(4, '0');
    final tail = p.period == 0
        ? (sale.termMonths == 0 ? 'CASH' : 'DP')
        : 'P${p.period.toString().padLeft(3, '0')}';
    return 'LP-${sale.soldDate.year}-$seq-$tail';
  }

  /// Builds the `payments` record for a lot payment.
  ///
  /// Pass [paidAt] when the money has been received (status paid). Leave it
  /// null to create a PENDING record (status unpaid, no paid date).
  Map<String, dynamic> _mirrorMap({
    required LotSaleModel sale,
    required LotPaymentModel p,
    required String recordedBy,
    required String method,
    DateTime? paidAt,
  }) {
    final isPaid = paidAt != null;
    final note = p.period == 0
        ? (sale.termMonths == 0 ? 'Lot purchase (cash)' : 'Lot down payment')
        : 'Lot installment · Period ${p.period}';

    final record = PaymentModel(
      id: mirrorId(sale.id, p.period),
      uid: sale.buyerUid,
      memberName: sale.buyerName,
      type: PaymentType.lotPayment,
      amount: p.amount,
      status: isPaid ? PaymentStatus.paid : PaymentStatus.unpaid,
      dueDate: p.dueDate,
      paidDate: paidAt,
      recordedBy: recordedBy,
      notes: note,
      createdAt: DateTime.now(),
      lotId: sale.lotId,
      lotLabel: buildLotLabel(
        block: sale.block,
        lotNumber: sale.lotNumber,
        phase: sale.phase,
      ),
      transactionId: _mirrorTxnId(sale, p),
      paidAmount: isPaid ? p.amount : 0,
      paymentMethod: isPaid ? method : '',
    );

    return {
      ...record.toMap(),
      // Extra keys: not part of PaymentModel (fromMap ignores them) but let us
      // trace / de-duplicate the mirror against its lot_payments source.
      'source': _mirrorSource,
      'saleId': sale.id,
      'period': p.period,
    };
  }

  /// Marks one lot_payments row paid AND updates/creates its `payments`
  /// record in a single batch, so the two collections can't drift apart.
  /// If a pending record already exists (cash / down payment), it is updated
  /// in place rather than duplicated.
  Future<void> _markPeriodPaid({
    required DocumentReference<Map<String, dynamic>> ref,
    required LotPaymentModel p,
    required String saleId,
    required String payer,
    required String paidBy,
    required PaymentMethod method,
  }) async {
    final sale = await getSale(saleId);
    final paidAt = DateTime.now();
    final batch = _db.batch();

    batch.update(ref, {
      'status': LotPaymentStatus.paid.name,
      'paidAt': Timestamp.fromDate(paidAt),
      'paidBy': paidBy,
      'payer': payer,
      'paymentMethod': method.name,
      'verifiedAt':
          method == PaymentMethod.cash ? Timestamp.fromDate(paidAt) : null,
    });

    if (sale != null && p.amount > 0) {
      batch.set(
        _mainPayments.doc(mirrorId(sale.id, p.period)),
        _mirrorMap(
          sale: sale,
          p: p,
          paidAt: paidAt,
          recordedBy: paidBy,
          method: method.name,
        ),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Use this from the Payments screen's "Mark Paid" for lot payment records.
  ///
  /// The `payments` document id encodes the sale and period
  /// (`lot_<saleId>_<period>`), so this finds the matching lot_payments row and
  /// marks BOTH sides paid together. Calling only the generic
  /// `markPaymentPaid` would leave `lot_payments` still pending.
  Future<void> markLotPaymentRecordPaid({
    required String paymentId,
    required String payer,
    required String paidBy,
    PaymentMethod method = PaymentMethod.cash,
  }) async {
    if (!paymentId.startsWith('lot_')) {
      throw Exception('Not a lot payment record.');
    }
    final body = paymentId.substring(4);
    final cut = body.lastIndexOf('_');
    final period = cut > 0 ? int.tryParse(body.substring(cut + 1)) : null;
    if (cut > 0 && period != null) {
      await markInstallmentPaid(
        saleId: body.substring(0, cut),
        period: period,
        payer: payer,
        paidBy: paidBy,
        method: method,
      );
      return;
    }

    // Legacy mirror id `lot_<lotPaymentsDocId>` (random doc id, no period).
    // Resolve through the lot_payments row itself.
    final lp = await _payments.doc(body).get();
    if (!lp.exists) {
      throw Exception('Unrecognized lot payment record id: $paymentId');
    }
    final data = lp.data()!;
    final legacySaleId = data['saleId'] as String? ?? '';
    final legacyPeriod = (data['period'] as num?)?.toInt() ?? -1;
    if (legacySaleId.isEmpty || legacyPeriod < 0) {
      throw Exception('Unrecognized lot payment record id: $paymentId');
    }

    await markInstallmentPaid(
      saleId: legacySaleId,
      period: legacyPeriod,
      payer: payer,
      paidBy: paidBy,
      method: method,
    );
    // _markPeriodPaid writes the canonical mirror; drop the legacy one so
    // the Payments screen doesn't list the same period twice.
    await _mainPayments.doc(paymentId).delete();
  }

  /// ONE-TIME catch-up: creates the `payments` record for every lot payment
  /// that is already PAID but has none. Safe to run repeatedly — records that
  /// already exist are skipped, so it never overwrites a pending record and
  /// never turns a pending payment into a paid one. Returns how many were
  /// created.
  Future<int> backfillLotPaymentRecords({String recordedBy = 'system'}) async {
    final paidSnap = await _payments
        .where('status', isEqualTo: LotPaymentStatus.paid.name)
        .get();
    if (paidSnap.docs.isEmpty) return 0;

    final existingSnap = await _mainPayments
        .where('source', isEqualTo: _mirrorSource)
        .get();
    final existing = existingSnap.docs.map((d) => d.id).toSet();

    final salesSnap = await _sales.get();
    final sales = {
      for (final d in salesSnap.docs)
        d.id: LotSaleModel.fromMap(d.data(), d.id),
    };

    final pending = <MapEntry<String, Map<String, dynamic>>>[];
    for (final d in paidSnap.docs) {
      final data = d.data();
      final p = LotPaymentModel.fromMap(data);
      final sale = sales[p.saleId];
      if (sale == null || p.amount <= 0) continue;

      final id = mirrorId(sale.id, p.period);
      if (existing.contains(id)) continue;

      pending.add(MapEntry(
        id,
        _mirrorMap(
          sale: sale,
          p: p,
          paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? p.dueDate,
          recordedBy: (data['paidBy'] as String?) ?? recordedBy,
          method: (data['paymentMethod'] as String?) ?? 'cash',
        ),
      ));
    }

    // Firestore caps a batch at 500 writes.
    for (var i = 0; i < pending.length; i += 400) {
      final batch = _db.batch();
      for (final e in pending.skip(i).take(400)) {
        batch.set(_mainPayments.doc(e.key), e.value);
      }
      await batch.commit();
    }
    return pending.length;
  }

  /// Throws [LotNotAvailableException] unless the lot can be sold. Returns
  /// the lot's CURRENT `isCorner` flag from Firestore (null when [lotId] is
  /// empty), so the sale is priced from the fresh doc rather than a stale
  /// in-memory LotModel.
  Future<bool?> _verifyLotAvailable({required String lotId}) async {
    if (lotId.isEmpty) return null;

    final snap = await _db.collection('lots').doc(lotId).get();

    if (!snap.exists) {
      throw LotNotAvailableException(lotId);
    }

    final data = snap.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    final uid = data['uid'];

    if (status != LotStatus.vacant.name &&
        status != LotStatus.forSale.name) {
      throw LotNotAvailableException(lotId);
    }

    if ((uid as String?)?.isNotEmpty == true) {
      throw LotNotAvailableException(lotId);
    }

    return data['isCorner'] as bool? ?? false;
  }

  /// Alias or method for registering a sale matching member registration wizard.
  Future<void> registerSale({
    required LotModel lot,
    required String buyerUid,
    required String buyerName,
    List<String> coOwnerUids = const [],
    required SaleType saleType,
    required double downPayment,
    required int termMonths,
    required double annualInterestRate,
    required DateTime soldDate,
    required String recordedBy,
  }) async {
    final effectiveTermMonths =
        saleType == SaleType.installment ? termMonths : 0;

    return recordSale(
      lot: lot,
      buyerUid: buyerUid,
      buyerName: buyerName,
      coOwnerUids: coOwnerUids,
      downPayment: downPayment,
      termMonths: effectiveTermMonths,
      annualInterestRate: annualInterestRate,
      soldDate: soldDate,
      recordedBy: recordedBy,
    );
  }

  /// Records a sale for [lot] to [buyerUid] / [buyerName].
  ///
  /// Nothing is marked paid at registration — money is only counted once it is
  /// received and the payment is marked paid.
  ///
  /// Cash:
  /// - One payment document, pending (scheduled), with a pending record in
  ///   the payment records.
  /// - Sale status active until that payment is marked paid, then paidOff.
  /// - Lot status occupied (reserved for the buyer).
  ///
  /// Installment:
  /// - Sale status active.
  /// - Payment documents generated for the schedule.
  /// - Period 0 down payment (when downPayment > 0) is pending too, with a
  ///   pending record in the payment records.
  /// - Lot status occupied.
  ///
  /// Corner lots are priced at the corner rate in force on [soldDate]
  /// (falling back to the normal rate when the row has no corner rate).
  Future<void> recordSale({
    required LotModel lot,
    required String buyerUid,
    required String buyerName,
    List<String> coOwnerUids = const [],
    required double downPayment,
    required int termMonths,
    required double annualInterestRate,
    required DateTime soldDate,
    required String recordedBy,
  }) async {
    final freshIsCorner = await _verifyLotAvailable(lotId: lot.id);
    final isCorner = freshIsCorner ?? lot.isCorner;

    // Fetch the rate in force on the sale date (sample rate if none).
    final rateSvc = RateService(db: _db);
    final salesRate = await rateSvc.getSalesRateFor(soldDate);
    final ratePerSqm = salesRate?.ratePerSqm;

    // Price comes from lot area (see LotPricing).
    final totalPrice = LotPricing.priceFor(
      lot,
      ratePerSqm: ratePerSqm,
      cornerRatePerSqm: salesRate?.cornerRatePerSqm,
      isCorner: isCorner,
    );
    final financedAmount = totalPrice - downPayment;

    final monthlyPayment = termMonths > 0
        ? LotPricing.monthlyFor(
            financedAmount,
            annualInterestRate,
            termMonths,
          )
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
      coOwnerUids: coOwnerUids,
      ownerUids: [buyerUid, ...coOwnerUids.toSet()],
      saleType:
          termMonths == 0 ? SaleType.cash : SaleType.installment,
      totalPrice: totalPrice,
      downPayment: downPayment,
      financedAmount: financedAmount,
      termMonths: termMonths,
      annualInterestRate: annualInterestRate,
      monthlyPayment: monthlyPayment,
      // Cash is no longer paidOff at registration: it stays active until the
      // payment is received and marked paid (_checkIfPaidOff then closes it).
      status: LotSaleStatus.active,
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

      // Every row starts out unpaid (scheduled) — including cash and the
      // down payment. They are marked paid later, when the money is received.
      batch.set(
        _payments.doc(),
        p.copyWith(
          status: LotPaymentStatus.scheduled,
          paidAt: null,
          paidBy: null,
        ).toMap(),
      );

      // Cash purchase / down payment: save a PENDING record in the payment
      // records right away so it shows up and can be marked paid on receipt.
      if ((isCash || isDown) && p.amount > 0) {
        batch.set(
          _mainPayments.doc(mirrorId(saleId, p.period)),
          _mirrorMap(
            sale: sale,
            p: p,
            recordedBy: recordedBy,
            method: 'cash',
          ),
        );
      }
    }

    batch.set(
      _ownerHistory.doc(),
      LotOwnershipRecord(
        lotId: lot.id,
        saleId: saleId,
        ownerUid: buyerUid,
        ownerName: buyerName,
        startedAt: soldDate,
        acquiredBy: 'sale',
        transferredBy: recordedBy,
      ).toMap(),
    );

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

  /// Next per-year sale sequence number.
  Future<int> _nextSaleSeq(int year) async {
    final snap = await _sales
        .where(
          'soldDate',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(DateTime(year, 1, 1)),
        )
        .where(
          'soldDate',
          isLessThan: Timestamp.fromDate(DateTime(year + 1, 1, 1)),
        )
        .get();

    if (snap.docs.isEmpty) return 1;

    var max = 0;

    for (final d in snap.docs) {
      final seq = (d.data()['saleSeq'] as num?)?.toInt() ?? 0;

      if (seq > max) max = seq;
    }

    return max + 1;
  }

  /// Records payment for the first unpaid period.
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
        await _markPeriodPaid(
          ref: doc.reference,
          p: p,
          saleId: saleId,
          payer: payer,
          paidBy: paidBy,
          method: method,
        );

        await _checkIfPaidOff(saleId);
        return;
      }
    }

    throw Exception('No unpaid periods for this sale.');
  }

  /// Checks whether all payments for a sale are paid.
  Future<void> _checkIfPaidOff(String saleId) async {
    final snap = await _payments
        .where('saleId', isEqualTo: saleId)
        .get();

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

  /// Closes a sale and voids scheduled payments.
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
        batch.update(
          doc.reference,
          {'status': LotPaymentStatus.void_.name},
        );
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

  /// The sale that currently belongs to [lotId]: the newest sale that has not
  /// been cancelled. Null when the lot has no sale on record.
  Future<LotSaleModel?> getCurrentSaleForLot(String lotId) async {
    final sales = await getAllSalesForLot(lotId);
    final live = sales.where((s) => s.status != LotSaleStatus.cancelled).toList()
      ..sort((a, b) => b.soldDate.compareTo(a.soldDate));
    return live.isEmpty ? null : live.first;
  }

  /// What is still owed on [saleId]: every period that is not paid, void or
  /// waived. This is the balance that stays with the lot when the owner changes.
  Future<double> outstandingBalanceForSale(String saleId) async {
    final snap = await _payments.where('saleId', isEqualTo: saleId).get();
    var total = 0.0;
    for (final d in snap.docs) {
      final p = LotPaymentModel.fromMap(d.data());
      if (p.status == LotPaymentStatus.paid ||
          p.status == LotPaymentStatus.void_ ||
          p.status == LotPaymentStatus.waived) {
        continue;
      }
      total += p.amount;
    }
    return total;
  }

  /// Ownership history of a lot, newest first.
  Stream<List<LotOwnershipRecord>> streamOwnershipHistory(String lotId) {
    return _ownerHistory
        .where('lotId', isEqualTo: lotId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotOwnershipRecord.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)));
  }

  /// Changes the owner of an already-owned lot.
  ///
  /// The outstanding balance stays with the lot: the sale is re-pointed at the
  /// new owner, so every unpaid period is now theirs to pay (and the Payments
  /// record written when a period is paid carries their name). Anything the
  /// previous owner already paid stays in their own payment records.
  ///
  /// Lot, sale and ownership history are updated in one batch.
  Future<void> changeLotOwner({
    required String lotId,
    required String newBuyerUid,
    required String newBuyerName,
    required String updatedBy,
    String notes = '',
  }) async {
    final lotRef = _db.collection('lots').doc(lotId);
    final lotSnap = await lotRef.get();
    if (!lotSnap.exists) throw LotNotAvailableException(lotId);

    final lotData = lotSnap.data() as Map<String, dynamic>;
    final oldUid = (lotData['uid'] as String?) ?? '';
    final oldName = (lotData['ownerName'] as String?) ?? '';
    if (oldUid == newBuyerUid) {
      throw Exception('That member already owns this lot.');
    }

    final sale = await getCurrentSaleForLot(lotId);
    final balance =
        sale == null ? 0.0 : await outstandingBalanceForSale(sale.id);
    final now = DateTime.now();

    final openSnap = await _ownerHistory
        .where('lotId', isEqualTo: lotId)
        .where('endedAt', isEqualTo: null)
        .get();

    final batch = _db.batch();

    if (openSnap.docs.isNotEmpty) {
      for (final d in openSnap.docs) {
        batch.update(d.reference, {
          'endedAt': Timestamp.fromDate(now),
          'balanceLeftBehind': balance,
        });
      }
    } else if (oldUid.isNotEmpty) {
      // Lot was owned before history existed — record the previous owner now.
      batch.set(
        _ownerHistory.doc(),
        LotOwnershipRecord(
          lotId: lotId,
          saleId: sale?.id ?? '',
          ownerUid: oldUid,
          ownerName: oldName,
          startedAt: sale?.soldDate ?? now,
          endedAt: now,
          acquiredBy: sale == null ? 'assignment' : 'sale',
          balanceLeftBehind: balance,
          transferredBy: updatedBy,
        ).toMap(),
      );
    }

    batch.set(
      _ownerHistory.doc(),
      LotOwnershipRecord(
        lotId: lotId,
        saleId: sale?.id ?? '',
        ownerUid: newBuyerUid,
        ownerName: newBuyerName,
        startedAt: now,
        acquiredBy: 'transfer',
        balanceTakenOver: balance,
        transferredBy: updatedBy,
        notes: notes,
      ).toMap(),
    );

    batch.set(
      lotRef,
      {
        'uid': newBuyerUid,
        'ownerName': newBuyerName,
        'updatedBy': updatedBy,
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    if (sale != null) {
      batch.update(_sales.doc(sale.id), {
        'buyerUid': newBuyerUid,
        'buyerName': newBuyerName,
        // Transfer replaces the whole ownership: prior co-owners are out.
        'coOwnerUids': [],
        'ownerUids': [newBuyerUid],
        'updatedBy': updatedBy,
        'updatedAt': Timestamp.now(),
      });
    }

    await batch.commit();
  }

  /// Gets payment report dataset.
  Future<List<Map<String, dynamic>>> getPaymentsReportDataset() async {
    final paymentsSnap = await _payments.get();
    final salesSnap = await _sales.get();

    final sales = {
      for (final doc in salesSnap.docs)
        doc.id: LotSaleModel.fromMap(doc.data(), doc.id),
    };

    return paymentsSnap.docs.map((doc) {
      final p = LotPaymentModel.fromMap(doc.data());
      final s = sales[p.saleId];

      return {
        'period': p.period,
        'amount': p.amount,
        'status': p.status.name,
        'buyerName': s?.buyerName ?? 'Unknown',
        'buyerUid': s?.buyerUid ?? '',
        'ownerUids': s?.ownerUids ?? const <String>[],
        'lotNumber': s?.lotNumber ?? 'Unknown',
        'soldDate': s?.soldDate,
        'dueDate': p.dueDate,
      };
    }).toList();
  }

  /// Streams sales for a specific lot.
  Stream<List<LotSaleModel>> streamSalesForLot(String lotId) {
    return _sales
        .where('lotId', isEqualTo: lotId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotSaleModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Streams payments for a specific sale.
  Stream<List<LotPaymentModel>> streamPaymentsForSale(String saleId) {
    return _payments
        .where('saleId', isEqualTo: saleId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotPaymentModel.fromMap(d.data()))
            .toList()
          ..sort((a, b) => a.period.compareTo(b.period)));
  }

  /// Gets a single sale.
  Future<LotSaleModel?> getSale(String saleId) async {
    final doc = await _sales.doc(saleId).get();

    if (!doc.exists) return null;

    return LotSaleModel.fromMap(doc.data()!, doc.id);
  }

  /// Streams all sales.
  Stream<List<LotSaleModel>> streamAllSales() {
    return _sales.snapshots().map((snap) => snap.docs
        .map((d) => LotSaleModel.fromMap(d.data(), d.id))
        .toList());
  }

  /// Gets all sales for a specific lot.
  Future<List<LotSaleModel>> getAllSalesForLot(String lotId) async {
    final snap = await _sales
        .where('lotId', isEqualTo: lotId)
        .get();

    return snap.docs
        .map((d) => LotSaleModel.fromMap(d.data(), d.id))
        .toList();
  }

  /// Streams sales where [memberUid] is the buyer or a co-owner.
  Stream<List<LotSaleModel>> streamSalesForMember(String memberUid) {
    if (memberUid.isEmpty) {
      return Stream.value(<LotSaleModel>[]);
    }

    return _sales
        .where('ownerUids', arrayContains: memberUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotSaleModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Streams every `lot_payments` schedule row for sales where [memberUid]
  /// is buyer or co-owner — the member's assessed installment obligations.
  /// Doc id is attached so `payment_allocations` rows can be matched back.
  Stream<List<LotPaymentModel>> streamLotPaymentsForMember(String memberUid) {
    if (memberUid.isEmpty) {
      return Stream.value(const <LotPaymentModel>[]);
    }

    return streamSalesForMember(memberUid).asyncMap((sales) async {
      final ids = sales.map((s) => s.id).toList();
      if (ids.isEmpty) return const <LotPaymentModel>[];
      // whereIn caps at 30; a member with 30+ financed lots is unrealistic
      // today, so fall back to a full scan filtered client-side.
      // ponytail: revisit if a member can ever hold that many sales.
      final snap = ids.length <= 30
          ? await _payments
              .where('saleId', whereIn: ids)
              .get()
          : await _payments.get();
      return snap.docs
          .map((d) => LotPaymentModel.fromMap(d.data(), d.id))
          .where((p) => ids.contains(p.saleId))
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });
  }

  /// Marks ONE specific installment period as paid.
  ///
  /// Unlike recordPayment(), this allows a specific period
  /// to be selected directly.
  Future<void> markInstallmentPaid({
    required String saleId,
    required int period,
    required String payer,
    required String paidBy,
    required PaymentMethod method,
  }) async {
    final snap = await _payments
        .where('saleId', isEqualTo: saleId)
        .get();

    for (final doc in snap.docs) {
      final p = LotPaymentModel.fromMap(doc.data());

      if (p.period != period) continue;

      if (p.status == LotPaymentStatus.paid) {
        throw Exception('Period $period is already paid.');
      }

      if (p.status == LotPaymentStatus.void_ ||
          p.status == LotPaymentStatus.waived) {
        throw Exception(
          'Period $period is ${p.status.label.toLowerCase()} '
          'and can\'t be marked paid.',
        );
      }

      await _markPeriodPaid(
        ref: doc.reference,
        p: p,
        saleId: saleId,
        payer: payer,
        paidBy: paidBy,
        method: method,
      );

      await _checkIfPaidOff(saleId);
      return;
    }

    throw Exception('Period $period not found for this sale.');
  }
}