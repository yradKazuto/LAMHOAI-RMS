// lib/core/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/enum_utils.dart';

// Kept in sync with web-admin/lib/core/models/payment_model.dart — the
// admin app is the source of truth for what gets written to Firestore.
enum PaymentStatus { paid, unpaid, overdue, waived }
enum PaymentType   { dues, membershipFee, lotPayment, penalty, specialAssessment, other }

const Map<PaymentStatus, String> _paymentStatusLabels = {
  PaymentStatus.paid: 'Paid',
  PaymentStatus.unpaid: 'Unpaid',
  PaymentStatus.overdue: 'Overdue',
  PaymentStatus.waived: 'Waived',
};

const Map<String, PaymentStatus> _paymentStatusLookup = {
  'paid': PaymentStatus.paid,
  'unpaid': PaymentStatus.unpaid,
  'overdue': PaymentStatus.overdue,
  'waived': PaymentStatus.waived,
};

const Map<PaymentType, String> _paymentTypeLabels = {
  PaymentType.dues: 'Monthly Dues',
  PaymentType.membershipFee: 'Membership Fee',
  PaymentType.lotPayment: 'Lot Amortization',
  PaymentType.penalty: 'Penalty',
  PaymentType.specialAssessment: 'Special Assessment',
  PaymentType.other: 'Other',
};

const Map<String, PaymentType> _paymentTypeLookup = {
  'dues': PaymentType.dues,
  'membershipfee': PaymentType.membershipFee,
  'lotpayment': PaymentType.lotPayment,
  'penalty': PaymentType.penalty,
  'specialassessment': PaymentType.specialAssessment,
};

extension PaymentStatusExt on PaymentStatus {
  String get label => enumLabel(this, _paymentStatusLabels);

  static PaymentStatus fromString(String? v) =>
      enumFromString(v, _paymentStatusLookup, defaultValue: PaymentStatus.unpaid);
}

extension PaymentTypeExt on PaymentType {
  String get label => enumLabel(this, _paymentTypeLabels);

  static PaymentType fromString(String? v) =>
      enumFromString(v, _paymentTypeLookup, defaultValue: PaymentType.other);
}

class PaymentModel {
  final String   id;
  final String   memberId;
  final String   memberName;
  final PaymentType type;
  final double   amount;
  final PaymentStatus status;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String?  recordedBy;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.type,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidDate,
    this.recordedBy,
    this.createdAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id:         doc.id,
      memberId:   d['uid']   as String? ?? '',
      memberName: d['memberName'] as String? ?? '',
      type:       PaymentTypeExt.fromString(d['type']   as String?),
      amount:     (d['amount'] as num?)?.toDouble() ?? 0.0,
      status:     PaymentStatusExt.fromString(d['status'] as String?),
      dueDate:    (d['dueDate']   as Timestamp?)?.toDate() ?? DateTime.now(),
      paidDate:   (d['paidDate']  as Timestamp?)?.toDate(),
      recordedBy: d['recordedBy'] as String?,
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Display label for the payment type (e.g. 'Monthly Dues').
  String get typeLabel => type.label;

  /// The status as it should actually be displayed right now.
  ///
  /// The stored `status` field only ever reflects what an admin explicitly
  /// set (paid/unpaid/overdue/waived) — nothing flips a record to
  /// 'overdue' server-side when its due date passes. So instead of
  /// trusting the raw `status` field alone, we derive it here: an unpaid
  /// payment whose dueDate is in the past is treated as overdue. This
  /// mirrors `PaymentDisplayStatus.displayStatus` in the web-admin app so
  /// both apps show the same thing for the same record.
  PaymentStatus get effectiveStatus {
    // Compare against the START of today so a record is not "overdue" on
    // its own due date (dueDate is stored at midnight, so comparing with
    // DateTime.now() flipped it to overdue at 12:00 AM of the due day).
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (status == PaymentStatus.unpaid && dueDate.isBefore(startOfToday)) {
      return PaymentStatus.overdue;
    }
    return status;
  }

  /// Display label for the status (e.g. 'Paid', 'Overdue').
  String get statusLabel => effectiveStatus.label;

  // ── Serialization ─────────────────────────────────────────────────────────
}