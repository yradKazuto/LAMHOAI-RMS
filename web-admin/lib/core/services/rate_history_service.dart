// core/services/rate_history_service.dart
//
// Monthly membership rate history, linked to the annual membership fee:
//
//   annual fee for a year = sum of that year's 12 monthly rates
//
// so a single rate of 150 gives 150 x 12 = 1800, and if the rate changes to
// 200 from November, the year's annual becomes 10 x 150 + 2 x 200 = 1900.
// Months before the change keep their old rate; only the months from the
// change onward go up.
//
// When a rate is added (or a scheduled one removed), every member whose
// annual fee for that year is still OPEN (unpaid/overdue) has their annual
// record and ledger moved by the difference, so the Annual screen's
// Amount/Balance follow the new rate. Members who already paid their annual
// fee in full are not touched.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monthly_rate_model.dart';
import '../models/payment_model.dart';

class RateHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _coll    = 'monthly_dues_rates';
  static const String _ledgers = 'member_ledgers';
  static const String _pays    = 'payments';

  Stream<List<MonthlyRateModel>> streamMonthlyRates() {
    return _db
        .collection(_coll)
        .orderBy('effectiveStart', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MonthlyRateModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// The rate that applies to [month] — the most recent rate entry
  /// whose effectiveStart is on or before the 1st of that month.
  Future<double> getRateForMonth(DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final snap = await _db
        .collection(_coll)
        .where('effectiveStart', isLessThanOrEqualTo: Timestamp.fromDate(monthStart))
        .orderBy('effectiveStart', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return 0.0;
    return MonthlyRateModel.fromMap(snap.docs.first.data(), snap.docs.first.id).amount;
  }

  /// The annual membership fee for [year]: the sum of the 12 monthly rates
  /// in effect during that year. Months before the very first rate on file
  /// use that first rate, so a single 150 rate gives 1800 for the whole year.
  /// Returns 0 when no rate exists at all.
  Future<double> getAnnualForYear(int year) async {
    final snap = await _db
        .collection(_coll)
        .orderBy('effectiveStart')
        .get();
    if (snap.docs.isEmpty) return 0.0;

    final rates = snap.docs
        .map((d) => MonthlyRateModel.fromMap(d.data(), d.id))
        .toList(); // ascending by effectiveStart

    var total = 0.0;
    for (var m = 1; m <= 12; m++) {
      final monthStart = DateTime(year, m, 1);
      var rate = rates.first.amount;
      for (final r in rates) {
        if (r.effectiveStart.isAfter(monthStart)) break;
        rate = r.amount;
      }
      total += rate;
    }
    return _round2(total);
  }

  /// Sets the monthly rate from an annual fee (annual / 12). Call this
  /// wherever the annual fee is saved, so "annual 1800" automatically means
  /// "monthly 150".
  ///
  /// First rate ever → effective January of the current year (so the whole
  /// year is covered). Otherwise → effective next month, like any other rate
  /// change.
  Future<void> setRatesFromAnnual({
    required double annual,
    required String setBy,
  }) async {
    if (annual.isNaN || annual.isInfinite || annual <= 0) {
      throw Exception('Annual fee must be greater than zero.');
    }
    final monthly = _round2(annual / 12);

    final existing = await _db.collection(_coll).limit(1).get();
    final now = DateTime.now();
    final effective = existing.docs.isEmpty
        ? DateTime(now.year, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    await addMonthlyRate(
      amount:         monthly,
      effectiveMonth: effective,
      setBy:          setBy,
    );
  }

  /// Adds a new rate, effective the 1st of [effectiveMonth].
  /// Only allows setting a rate for next month onward — never the
  /// current month or the past.
  ///
  /// Also moves every open annual fee for that year by the difference
  /// (new rate − old rate) × the number of months the new rate covers.
  Future<void> addMonthlyRate({
    required double   amount,
    required DateTime effectiveMonth,
    required String   setBy,
  }) async {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw Exception('Rate must be greater than zero.');
    }

    final now               = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final requestedStart    = DateTime(effectiveMonth.year, effectiveMonth.month, 1);

    // The "next month or later" rule protects months that were already
    // billed — but with no rate on file yet nothing has been billed, and the
    // rule would make it impossible to ever bill the current month. So the
    // very first rate may start in any month.
    final existing = await _db.collection(_coll).limit(1).get();
    final isFirstRate = existing.docs.isEmpty;

    if (!isFirstRate && !requestedStart.isAfter(currentMonthStart)) {
      throw Exception('New rate must take effect next month or later.');
    }

    // Two rates with the same start month would make getRateForMonth()
    // pick one arbitrarily.
    final sameMonth = await _db
        .collection(_coll)
        .where('effectiveStart', isEqualTo: Timestamp.fromDate(requestedStart))
        .limit(1)
        .get();
    if (sameMonth.docs.isNotEmpty) {
      throw Exception('A rate already starts in that month.');
    }

    // What the new rate replaces, and how far it reaches (until the next
    // already-scheduled rate, or the end of that year).
    final previousRate = isFirstRate ? 0.0 : await getRateForMonth(requestedStart);
    final nextStart    = await _nextRateStartAfter(requestedStart);

    final ref = _db.collection(_coll).doc();
    await ref.set(MonthlyRateModel(
      id:             ref.id,
      amount:         amount,
      effectiveStart: requestedStart,
      setBy:          setBy,
      createdAt:      now,
    ).toMap());

    if (!isFirstRate) {
      final months = _monthsCovered(requestedStart, nextStart);
      await _adjustOpenAnnualFees(
        year:  requestedStart.year,
        delta: _round2((amount - previousRate) * months),
      );
    }
  }

  /// Removes a rate that has NOT started yet, so a typo in a scheduled rate
  /// can be corrected. A rate that has already started is never removable —
  /// months billed under it keep that rate. Open annual fees are moved back
  /// by the same amount the rate had added.
  Future<void> deleteScheduledRate(String id) async {
    final ref  = _db.collection(_coll).doc(id);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) return;

    final rate = MonthlyRateModel.fromMap(snap.data()!, snap.id);
    final now  = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    if (!rate.effectiveStart.isAfter(currentMonthStart)) {
      throw Exception('Only a rate that has not started yet can be removed.');
    }

    // The rate that takes over once this one is gone.
    final prevSnap = await _db
        .collection(_coll)
        .where('effectiveStart', isLessThan: Timestamp.fromDate(rate.effectiveStart))
        .orderBy('effectiveStart', descending: true)
        .limit(1)
        .get();
    final nextStart = await _nextRateStartAfter(rate.effectiveStart);

    await ref.delete();

    if (prevSnap.docs.isNotEmpty) {
      final prevAmount = MonthlyRateModel.fromMap(
              prevSnap.docs.first.data(), prevSnap.docs.first.id)
          .amount;
      final months = _monthsCovered(rate.effectiveStart, nextStart);
      await _adjustOpenAnnualFees(
        year:  rate.effectiveStart.year,
        delta: _round2((prevAmount - rate.amount) * months),
      );
    }
  }

  // ── internals ─────────────────────────────────────────────────────────────

  double _round2(double v) => (v * 100).round() / 100;

  /// Start date of the first rate that begins after [start], or null.
  Future<DateTime?> _nextRateStartAfter(DateTime start) async {
    final snap = await _db
        .collection(_coll)
        .where('effectiveStart', isGreaterThan: Timestamp.fromDate(start))
        .orderBy('effectiveStart')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return MonthlyRateModel.fromMap(snap.docs.first.data(), snap.docs.first.id)
        .effectiveStart;
  }

  /// Months a rate starting at [start] applies within [start]'s year: until
  /// [nextStart] if that comes first, otherwise December.
  int _monthsCovered(DateTime start, DateTime? nextStart) {
    final yearEnd = DateTime(start.year + 1, 1, 1);
    final end = (nextStart != null && nextStart.isBefore(yearEnd))
        ? nextStart
        : yearEnd;
    return (end.year - start.year) * 12 + end.month - start.month;
  }

  /// Adds [delta] to every OPEN (unpaid/overdue) annual membership fee whose
  /// due date falls in [year], and to the matching member ledger
  /// (annualTarget + currentBalance). Paid / waived annual fees are left
  /// alone, and nothing goes below zero.
  Future<void> _adjustOpenAnnualFees({
    required int    year,
    required double delta,
  }) async {
    if (delta == 0) return;

    final start = DateTime(year, 1, 1);
    final end   = DateTime(year + 1, 1, 1);

    // Same (type, dueDate range) query the app already uses, so no new
    // index is needed; status is filtered here instead.
    final paySnap = await _db
        .collection(_pays)
        .where('type', isEqualTo: PaymentType.membershipFee.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final open = paySnap.docs.where((d) {
      final s = d.data()['status'] as String?;
      return s == PaymentStatus.unpaid.name || s == PaymentStatus.overdue.name;
    }).toList();
    if (open.isEmpty) return;

    final ledgerSnap = await _db.collection(_ledgers).get();
    final ledgers = {for (final d in ledgerSnap.docs) d.id: d};

    // Two writes per record (payment + ledger) → 200 records per batch,
    // safely under Firestore's 500-operation limit.
    const chunk = 200;
    for (var s = 0; s < open.length; s += chunk) {
      final e     = (s + chunk < open.length) ? s + chunk : open.length;
      final batch = _db.batch();

      for (var i = s; i < e; i++) {
        final doc    = open[i];
        final data   = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final newAmt = amount + delta;
        batch.update(doc.reference, {'amount': newAmt < 0 ? 0.0 : newAmt});

        final uid    = data['uid'] as String? ?? '';
        final ledger = ledgers[uid];
        if (ledger != null && (ledger.data()['year'] as num?)?.toInt() == year) {
          final l       = ledger.data();
          final target  = (l['annualTarget']   as num?)?.toDouble() ?? 0.0;
          final balance = (l['currentBalance'] as num?)?.toDouble() ?? 0.0;
          final newBal  = balance + delta;
          final newTgt  = target + delta;
          batch.update(ledger.reference, {
            'annualTarget':   newTgt < 0 ? 0.0 : newTgt,
            'currentBalance': newBal < 0 ? 0.0 : newBal,
            'updatedAt':      Timestamp.now(),
          });
        }
      }
      await batch.commit();
    }
  }
}