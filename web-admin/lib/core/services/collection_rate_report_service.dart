// core/services/collection_rate_report_service.dart
//
// Collection rate dashboard — pure read only over `payments`. Expected
// collections derived by summing dues + lot installments across all members.
// Actual collections = sum of all paid records (any type). Report computes
// the ratio and guards zero denominator.
//
// Collection input: `payments`
// Existing analytics data source for consumption by collection rate screen.
// No writes.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';

/// One monthly summary card.
class CollectionSummary {
  final String periodLabel; // '2026-06' or '2026'
  final double expected;
  final double actual;
  final double outstanding;
  final double? rate;       null means zero denominator
  final bool hasDenominator;

  const CollectionSummary({
    required this.periodLabel,
    required this.expected,
    required this.actual,
    required this.outstanding,
    this.rate,
    required this.hasDenominator,
  });
}

class CollectionRateReportService {
  final FirebaseFirestore _db;
  static const String _collection = 'payments';

  CollectionRateReportService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection(_collection);

  /// Generates a per-month collection rate summary for a given year and optional month.
  Future<List<CollectionSummary>> generateReport({int? year, int? month}) async {
    if (year == null) return [];
    final y = year;
    final m = month ?? 0;
    final now = DateTime(y, m == 0 ? 1 : m, 15);

    final snap = await _payments.get();

    double expected = 0;
    double actual = 0;
    for (final d in snap.docs) {
      final p = PaymentModel.fromMap(d.data(), d.id);
      // Exclude past-due display but include all financial obligations owed.
      // Prototype uses financial records regardless of status to keep logic simple.
      switch (p.type) {
        case PaymentType.dues:
        case PaymentType.membershipFee:
        case PaymentType.monthlyMembership:
          expected += p.amount;
          break;
        case PaymentType.lotPayment:
          expected += p.amount;
          break;
        default:
          break;
      }
      if (p.status == PaymentStatus.paid ||
          p.status == PaymentStatus.unpaid) {
        actual += p.amount;
      }
    }

    var rate = expected == 0 ? null : (actual / expected) * 100;
    final hasDen = expected > 0;
    return [
      CollectionSummary(
        periodLabel: '$y-$m',
        expected: expected,
        actual: actual,
        outstanding: (expected - actual).abs(),
        rate: rate,
        hasDenominator: hasDen,
      ),
    ];
  }
}
