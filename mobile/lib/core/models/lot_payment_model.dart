// core/models/lot_payment_model.dart
//
// Mirrors web-admin/lib/core/models/lot_payment_model.dart — one row of a lot's
// amortization schedule (period 0 = down payment / cash lump, 1..N =
// installments). Read-only in the member app: it drives the "My Lots" view
// and the per-lot statement, but the member app never writes it.
//
// Collection: `lot_payments`

import 'package:cloud_firestore/cloud_firestore.dart';

enum LotPaymentStatus { scheduled, paid, overdue, waived, void_ }

const Map<LotPaymentStatus, String> _lotPaymentStatusLabels = {
  LotPaymentStatus.scheduled: 'Scheduled',
  LotPaymentStatus.paid: 'Paid',
  LotPaymentStatus.overdue: 'Overdue',
  LotPaymentStatus.waived: 'Waived',
  LotPaymentStatus.void_: 'Void',
};

const Map<String, LotPaymentStatus> _lotPaymentStatusLookup = {
  'scheduled': LotPaymentStatus.scheduled,
  'paid': LotPaymentStatus.paid,
  'overdue': LotPaymentStatus.overdue,
  'waived': LotPaymentStatus.waived,
  'void': LotPaymentStatus.void_,
};

extension LotPaymentStatusExt on LotPaymentStatus {
  String get label => _lotPaymentStatusLabels[this] ?? name;

  static LotPaymentStatus fromString(String? v) =>
      _lotPaymentStatusLookup[v?.toLowerCase()] ?? LotPaymentStatus.scheduled;
}

class LotPaymentModel {
  final String id;
  final String saleId;
  final String lotId;
  final int period;
  final String transactionId;
  final DateTime dueDate;
  final double amount;
  final double remainingBalance;
  final LotPaymentStatus status;
  final double paidAmount;
  final double penaltyAmount;
  final DateTime? paidAt;

  const LotPaymentModel({
    required this.id,
    required this.saleId,
    required this.lotId,
    required this.period,
    required this.transactionId,
    required this.dueDate,
    required this.amount,
    required this.remainingBalance,
    required this.status,
    this.paidAmount = 0.0,
    this.penaltyAmount = 0.0,
    this.paidAt,
  });

  factory LotPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return LotPaymentModel(
      id:              id,
      saleId:          map['saleId'] as String? ?? '',
      lotId:           map['lotId'] as String? ?? '',
      period:          (map['period'] as num?)?.toInt() ?? 0,
      transactionId:   map['transactionId'] as String? ?? '',
      dueDate:         (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount:          (map['amount'] as num?)?.toDouble() ?? 0.0,
      remainingBalance:(map['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      status:          LotPaymentStatusExt.fromString(map['status'] as String?),
      paidAmount:      (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      penaltyAmount:   (map['penaltyAmount'] as num?)?.toDouble() ?? 0.0,
      paidAt:          (map['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The status as it should actually be displayed right now. Mirrors
  /// `LotPaymentModel.displayStatus` in web-admin: nothing flips a row to
  /// 'overdue' server-side when its due date passes, so an unpaid row whose
  /// dueDate is in the past is shown as overdue here too.
  LotPaymentStatus get effectiveStatus {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (status == LotPaymentStatus.scheduled &&
        dueDate.isBefore(startOfToday)) {
      return LotPaymentStatus.overdue;
    }
    return status;
  }
}

/// Total still owed on a lot's schedule: every row that is not paid, waived
/// or void, minus whatever was already paid against it. This is the same
/// "remaining schedule" balance web-admin's statement shows — not a
/// recomputation of amortization.
double lotBalanceOwed(Iterable<LotPaymentModel> rows) {
  var owed = 0.0;
  for (final r in rows) {
    final status = r.effectiveStatus;
    if (status == LotPaymentStatus.paid ||
        status == LotPaymentStatus.waived ||
        status == LotPaymentStatus.void_) {
      continue;
    }
    final left = r.amount - r.paidAmount;
    if (left > 0) owed += left;
  }
  return owed;
}