// core/services/ar_aging_report_service.dart
//
// Accounts Receivable Aging Report — pure read only. Does NOT modify any
// existing payment records or allocations. Derives outstanding obligations
// from existing PaymentModel and LotSaleModel docs and buckets them by overdue
// days relative to each record's dueDate.
//
// Collection inputs: `payments`, `lot_sales`. Used by AR Aging report only.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lot_sale_model.dart';
import '../models/payment_model.dart';

/// One aging bucket keyed by member name + lot label. Per prototype grouping;
/// unique reporting keys enforce no double counting.
class AgingBucket {
  final String key;
  final double amount; // outstanding principal portion only
  final bool isLotInstallment;

  const AgingBucket({
    required this.key,
    required this.amount,
    required this.isLotInstallment,
  });
}

class ArAgingReport {
  final int totalOutstanding;
  final Map<String, double> bucketCurrent;
  final Map<String, double> bucket1To30;
  final Map<String, double> bucket31To60;
  final Map<String, double> bucket61To90;
  final Map<String, double> bucket90Plus;

  const ArAgingReport({
    required this.totalOutstanding,
    this.bucketCurrent = const {},
    this.bucket1To30 = const {},
    this.bucket31To60 = const {},
    this.bucket61To90 = const {},
    this.bucket90Plus = const {},
  });

  double get totalCollected => [
        bucketCurrent,
        bucket1To30,
        bucket31To60,
        bucket61To90,
        bucket90Plus,
      ].expand((m) => m.values).fold(0.0, (s, v) => s + v);
}

/// Computes overdue days as days elapsed since dueDate as of [asOf].
int _overdueDays(DateTime dueDate, DateTime asOf) {
  if (!dueDate.isBefore(asOf)) return 0;
  final diff = asOf.difference(dueDate).inDays;
  return diff < 0 ? 0 : diff;
}

class ArAgingReportService {
  final FirebaseFirestore _db;
  static const String _paymentsCollection = 'payments';
  static const String _lotSalesCollection = 'lot_sales';

  ArAgingReportService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Generates an AR aging summary over all `payments` docs where type
  /// includes lotPayment, membership fee, monthly dues, monthly membership.
  Future<ArAgingReport> generateReport({DateTime? asOf}) async {
    final now  = asOf ?? DateTime.now();
    final snap = await _db.collection(_paymentsCollection).get();

    final current = <String, double>{};
    final b130    = <String, double>{};
    final b3160   = <String, double>{};
    final b6190   = <String, double>{};
    final b90plus = <String, double>{};

    void add(Map<String, double> bucket, String key, double value) {
      bucket[key] = (bucket[key] ?? 0) + value;
    }

    for (final d in snap.docs) {
      final p = PaymentModel.fromMap(d.data(), d.id);
      // Skip paid, waived, penalty-only records from aging base line.
      // Penalty increments handled separately below if needed; prototype shows principal only.
      final balance = p.amount - (p.paidAmount ?? 0);
      if (balance <= 0) continue;

      final key = '${p.memberName}:${p.lotLabel}';
      switch (_bucketIndex(balance, p.dueDate, now)) {
        case 0:  add(current, key, balance);  break;
        case 1:  add(b130, key, balance);     break;
        case 2:  add(b3160, key, balance);    break;
        case 3:  add(b6190, key, balance);    break;
        default: add(b90plus, key, balance);  break;
      }
    }

    return ArAgingReport(
      totalOutstanding: current.length +
          b130.length +
          b3160.length +
          b6190.length +
          b90plus.length,
      bucketCurrent: current,
      bucket1To30:   b130,
      bucket31To60:  b3160,
      bucket61To90:  b6190,
      bucket90Plus:  b90plus,
    );
  }

  int _bucketIndex(double balance, DateTime dueDate, DateTime asOf) {
    final days = _overdueDays(dueDate, asOf);
    if (days <= 0) return 0;
    if (days <= 30) return 1;
    if (days <= 60) return 2;
    if (days <= 90) return 3;
    return 4;
  }
}