// core/services/analytics_service.dart
// Aggregates Firestore data for dashboard charts

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../models/member_model.dart';

class MonthlyCollection {
  final String month; // e.g. "Jan", "Feb"
  final int    year;
  final double total;

  const MonthlyCollection({
    required this.month,
    required this.year,
    required this.total,
  });
}

class MemberStatusBreakdown {
  final int active;
  final int inactive;
  final int delinquent;
  final int total;

  const MemberStatusBreakdown({
    required this.active,
    required this.inactive,
    required this.delinquent,
    required this.total,
  });

  double get activePercent  => total == 0 ? 0 : active  / total * 100;
  double get complianceRate => total == 0 ? 0 : (active + inactive) / total * 100;
}

class PaymentStatusBreakdown {
  final int paid;
  final int unpaid;
  final int overdue;
  final int waived;
  final int total;

  const PaymentStatusBreakdown({
    required this.paid,
    required this.unpaid,
    required this.overdue,
    required this.waived,
    required this.total,
  });

  double get paidPercent => total == 0 ? 0 : paid / total * 100;
}

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Monthly collections for the last N months ─────────────────────────────
  Future<List<MonthlyCollection>> getMonthlyCollections({
    int months = 6,
  }) async {
    final now   = DateTime.now();
    final result = <MonthlyCollection>[];

    for (int i = months - 1; i >= 0; i--) {
      final date       = DateTime(now.year, now.month - i, 1);
      final startOfMonth = DateTime(date.year, date.month, 1);
      final endOfMonth   = DateTime(date.year, date.month + 1, 1);

      final snap = await _db
          .collection('payments')
          .where('status', isEqualTo: PaymentStatus.paid.name)
          .where('dueDate',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(startOfMonth))
          .where('dueDate',
              isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      final total = snap.docs.fold<double>(
        0.0,
        (sum, doc) =>
            sum +
            ((doc.data() as Map<String, dynamic>)['amount']
                    as num? ??
                0)
                .toDouble(),
      );

      result.add(MonthlyCollection(
        month: _monthLabel(date.month),
        year:  date.year,
        total: total,
      ));
    }

    return result;
  }

  // ── Member status breakdown ───────────────────────────────────────────────
  Future<MemberStatusBreakdown> getMemberStatusBreakdown() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'member')
        .get();

    int active = 0, inactive = 0, delinquent = 0;

    for (final doc in snap.docs) {
      final data   = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'active';
      switch (status) {
        case 'active':      active++;     break;
        case 'inactive':    inactive++;   break;
        case 'delinquent':  delinquent++; break;
      }
    }

    return MemberStatusBreakdown(
      active:     active,
      inactive:   inactive,
      delinquent: delinquent,
      total:      active + inactive + delinquent,
    );
  }

  // ── Payment status breakdown ──────────────────────────────────────────────
  Future<PaymentStatusBreakdown> getPaymentStatusBreakdown() async {
    final snap = await _db.collection('payments').get();

    int paid = 0, unpaid = 0, overdue = 0, waived = 0;

    for (final doc in snap.docs) {
      final data   = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'unpaid';
      switch (status) {
        case 'paid':    paid++;    break;
        case 'unpaid':  unpaid++;  break;
        case 'overdue': overdue++; break;
        case 'waived':  waived++;  break;
      }
    }

    return PaymentStatusBreakdown(
      paid:    paid,
      unpaid:  unpaid,
      overdue: overdue,
      waived:  waived,
      total:   paid + unpaid + overdue + waived,
    );
  }

  // ── Total collected this month ────────────────────────────────────────────
  Future<double> getCollectedThisMonth() async {
    final now          = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth   = DateTime(now.year, now.month + 1, 1);

    final snap = await _db
        .collection('payments')
        .where('status', isEqualTo: PaymentStatus.paid.name)
        .where('paidDate',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(startOfMonth))
        .where('paidDate',
            isLessThan: Timestamp.fromDate(endOfMonth))
        .get();

    return snap.docs.fold<double>(
      0.0,
      (sum, doc) =>
          sum +
          ((doc.data() as Map<String, dynamic>)['amount']
                  as num? ??
              0)
              .toDouble(),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  String _monthLabel(int month) {
    const labels = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return labels[month];
  }
}