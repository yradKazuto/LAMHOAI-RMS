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
  final int total;

  const PaymentStatusBreakdown({
    required this.paid,
    required this.unpaid,
    required this.overdue,
    required this.total,
  });

  double get paidPercent => total == 0 ? 0 : paid / total * 100;
}

class _PaidRecord {
  final double   amount;
  final DateTime paidDate;
  const _PaidRecord({required this.amount, required this.paidDate});
}

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Monthly collections for the last N months ─────────────────────────────
  // Keyed by paidDate (when the cash actually came in), NOT dueDate — a
  // payment due in September but paid in October (overdue, penalty
  // applied) belongs in October's bar, matching getCollectedThisMonth()
  // right above it on the Analytics screen. Filtering by dueDate instead
  // would silently fold that payment back into September, which by the
  // time October rolls around nobody is looking at anymore.
  Future<List<MonthlyCollection>> getMonthlyCollections({
    int months = 6,
  }) async {
    final now   = DateTime.now();
    final result = <MonthlyCollection>[];

    // One query for the whole window instead of one per month.
    final windowStart = DateTime(now.year, now.month - (months - 1), 1);
    final windowEnd   = DateTime(now.year, now.month + 1, 1);
    final paid = await _paidBetween(windowStart, windowEnd);

    for (int i = months - 1; i >= 0; i--) {
      final date         = DateTime(now.year, now.month - i, 1);
      final startOfMonth = DateTime(date.year, date.month, 1);
      final endOfMonth   = DateTime(date.year, date.month + 1, 1);

      final total = paid
          .where((p) =>
              !p.paidDate.isBefore(startOfMonth) &&
              p.paidDate.isBefore(endOfMonth))
          .fold<double>(0.0, (sum, p) => sum + p.amount);

      result.add(MonthlyCollection(
        month: _monthLabel(date.month),
        year:  date.year,
        total: total,
      ));
    }

    return result;
  }

  // Paid payments whose paidDate falls in [start, end).
  //
  // Deliberately filters on paidDate ONLY and checks status == paid in
  // code. A status + paidDate query needs a composite index; when that
  // index is missing Firestore rejects the whole query, and the Analytics
  // screen quietly fell back to "No data available" / ₱0 even though the
  // payments were saved correctly. A range on a single field uses
  // Firestore's automatic index, so there is nothing to set up. Unpaid
  // records have no paidDate, so they never match the range anyway.
  Future<List<_PaidRecord>> _paidBetween(
      DateTime start, DateTime end) async {
    final snap = await _db
        .collection('payments')
        .where('paidDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('paidDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final out = <_PaidRecord>[];
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['status'] as String?) != PaymentStatus.paid.name) continue;
      final ts = data['paidDate'] as Timestamp?;
      if (ts == null) continue;
      out.add(_PaidRecord(
        amount:   (data['amount'] as num? ?? 0).toDouble(),
        paidDate: ts.toDate(),
      ));
    }
    return out;
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
  // Computes the EFFECTIVE status per record (unpaid + dueDate passed =>
  // overdue) rather than trusting the raw stored `status` field. The stored
  // field is only kept accurate by syncOverdueStatuses(), which runs when
  // an admin opens Payments or Reports — a dashboard viewed before either
  // of those would otherwise undercount overdue and overcount unpaid.
  Future<PaymentStatusBreakdown> getPaymentStatusBreakdown() async {
    final snap = await _db.collection('payments').get();
    final now  = DateTime.now();

    // Waived is no longer a status the app offers. Any old waived records
    // are simply left out of the breakdown (nothing is owed on them), so
    // they can't skew the paid percentage.
    int paid = 0, unpaid = 0, overdue = 0;

    for (final doc in snap.docs) {
      final data   = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'unpaid';
      final dueTs  = data['dueDate'] as Timestamp?;
      final dueDate = dueTs?.toDate();

      final effective = (status == 'unpaid' &&
              dueDate != null &&
              dueDate.isBefore(now))
          ? 'overdue'
          : status;

      switch (effective) {
        case 'paid':    paid++;    break;
        case 'unpaid':  unpaid++;  break;
        case 'overdue': overdue++; break;
      }
    }

    return PaymentStatusBreakdown(
      paid:    paid,
      unpaid:  unpaid,
      overdue: overdue,
      total:   paid + unpaid + overdue,
    );
  }

  // ── Total collected this month ────────────────────────────────────────────
  Future<double> getCollectedThisMonth() async {
    final now          = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth   = DateTime(now.year, now.month + 1, 1);

    final paid = await _paidBetween(startOfMonth, endOfMonth);
    return paid.fold<double>(0.0, (sum, p) => sum + p.amount);
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