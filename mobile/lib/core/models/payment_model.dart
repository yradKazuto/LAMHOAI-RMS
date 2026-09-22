// lib/core/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Kept in sync with web-admin/lib/core/models/payment_model.dart — the
// admin app is the source of truth for what gets written to Firestore.
enum PaymentStatus { paid, unpaid, overdue, waived }
enum PaymentType   { dues, membershipFee, penalty, specialAssessment, other }

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
      type:       _typeFromString(d['type']   as String?),
      amount:     (d['amount'] as num?)?.toDouble() ?? 0.0,
      status:     _statusFromString(d['status'] as String?),
      dueDate:    (d['dueDate']   as Timestamp?)?.toDate() ?? DateTime.now(),
      paidDate:   (d['paidDate']  as Timestamp?)?.toDate(),
      recordedBy: d['recordedBy'] as String?,
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  String get typeLabel {
    switch (type) {
      case PaymentType.dues:              return 'Monthly Dues';
      case PaymentType.membershipFee:     return 'Membership Fee';
      case PaymentType.penalty:           return 'Penalty';
      case PaymentType.specialAssessment: return 'Special Assessment';
      case PaymentType.other:             return 'Other';
    }
  }

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
    if (status == PaymentStatus.unpaid && dueDate.isBefore(DateTime.now())) {
      return PaymentStatus.overdue;
    }
    return status;
  }

  String get statusLabel {
    switch (effectiveStatus) {
      case PaymentStatus.paid:    return 'Paid';
      case PaymentStatus.unpaid:  return 'Unpaid';
      case PaymentStatus.overdue: return 'Overdue';
      case PaymentStatus.waived:  return 'Waived';
    }
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static PaymentStatus _statusFromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'paid':    return PaymentStatus.paid;
      case 'unpaid':  return PaymentStatus.unpaid;
      case 'overdue': return PaymentStatus.overdue;
      case 'waived':  return PaymentStatus.waived;
      default:        return PaymentStatus.unpaid;
    }
  }

  static PaymentType _typeFromString(String? v) {
    switch (v) {
      case 'dues':              return PaymentType.dues;
      case 'membershipFee':     return PaymentType.membershipFee;
      case 'penalty':           return PaymentType.penalty;
      case 'specialAssessment': return PaymentType.specialAssessment;
      default:                  return PaymentType.other;
    }
  }
}