// core/services/rate_history_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/monthly_rate_model.dart';

class RateHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _coll = 'monthly_dues_rates';

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

  /// Adds a new rate, effective the 1st of [effectiveMonth].
  /// Only allows setting a rate for next month onward — never the
  /// current month or the past.
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

    final ref = _db.collection(_coll).doc();
    await ref.set(MonthlyRateModel(
      id:             ref.id,
      amount:         amount,
      effectiveStart: requestedStart,
      setBy:          setBy,
      createdAt:      now,
    ).toMap());
  }

  /// Removes a rate that has NOT started yet, so a typo in a scheduled rate
  /// can be corrected. A rate that has already started is never removable —
  /// months billed under it keep that rate.
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
    await ref.delete();
  }
}