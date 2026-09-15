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
    final now               = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart    = DateTime(now.year, now.month + 1, 1);
    final requestedStart    = DateTime(effectiveMonth.year, effectiveMonth.month, 1);

    if (!requestedStart.isAfter(currentMonthStart)) {
      throw Exception('New rate must take effect next month or later.');
    }

    final ref = _db.collection(_coll).doc();
    await ref.set(MonthlyRateModel(
      id:             ref.id,
      amount:         amount,
      effectiveStart: nextMonthStart.isAfter(requestedStart) ? nextMonthStart : requestedStart,
      setBy:          setBy,
      createdAt:      now,
    ).toMap());
  }
}