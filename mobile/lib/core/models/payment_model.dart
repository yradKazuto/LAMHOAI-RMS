// lib/core/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { paid, pending, overdue, unknown }
enum PaymentType   { monthly, annual, assessment, unknown }

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
      memberName: d['displayName'] as String? ?? '',
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
      case PaymentType.monthly:    return 'Monthly Due';
      case PaymentType.annual:     return 'Annual Membership Fee';
      case PaymentType.assessment: return 'Special Assessment';
      default:                     return 'Payment';
    }
  }

  /// The status as it should actually be displayed right now.
  ///
  /// Firestore only ever stores 'paid' or 'pending' — nothing flips a
  /// record to 'overdue' server-side when its due date passes. So instead
  /// of trusting the raw `status` field, we derive it here: a paid payment
  /// stays paid, but a pending payment whose dueDate is in the past is
  /// treated as overdue.
  PaymentStatus get effectiveStatus {
    if (status == PaymentStatus.paid) return PaymentStatus.paid;
    if (dueDate.isBefore(DateTime.now())) return PaymentStatus.overdue;
    return status;
  }

  String get statusLabel {
    switch (effectiveStatus) {
      case PaymentStatus.paid:    return 'Paid';
      case PaymentStatus.pending: return 'Pending';
      case PaymentStatus.overdue: return 'Overdue';
      default:                    return 'Unknown';
    }
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static PaymentStatus _statusFromString(String? v) {
    switch (v) {
      case 'paid':    return PaymentStatus.paid;
      case 'pending': return PaymentStatus.pending;
      case 'overdue': return PaymentStatus.overdue;
      default:        return PaymentStatus.unknown;
    }
  }

  static PaymentType _typeFromString(String? v) {
    switch (v) {
      case 'monthly':    return PaymentType.monthly;
      case 'annual':     return PaymentType.annual;
      case 'assessment': return PaymentType.assessment;
      default:           return PaymentType.unknown;
    }
  }
}