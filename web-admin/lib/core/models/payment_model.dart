// core/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType { dues, penalty, specialAssessment, other }

extension PaymentTypeExt on PaymentType {
  String get label {
    switch (this) {
      case PaymentType.dues:              return 'Monthly Dues';
      case PaymentType.penalty:           return 'Penalty';
      case PaymentType.specialAssessment: return 'Special Assessment';
      case PaymentType.other:             return 'Other';
    }
  }

  static PaymentType fromString(String? v) {
    switch (v) {
      case 'dues':              return PaymentType.dues;
      case 'penalty':           return PaymentType.penalty;
      case 'specialAssessment': return PaymentType.specialAssessment;
      default:                  return PaymentType.other;
    }
  }
}

enum PaymentStatus { paid, unpaid, overdue, waived }

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:    return 'Paid';
      case PaymentStatus.unpaid:  return 'Unpaid';
      case PaymentStatus.overdue: return 'Overdue';
      case PaymentStatus.waived:  return 'Waived';
    }
  }

  static PaymentStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'paid':    return PaymentStatus.paid;
      case 'unpaid':  return PaymentStatus.unpaid;
      case 'overdue': return PaymentStatus.overdue;
      case 'waived':  return PaymentStatus.waived;
      default:        return PaymentStatus.unpaid;
    }
  }
}

class PaymentModel {
  final String id;
  final String uid;          // member's uid — matches Firestore field
  final String memberName;
  final PaymentType type;
  final double amount;
  final PaymentStatus status;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String recordedBy;
  final String notes;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.uid,         // fixed: was memberId
    required this.memberName,
    required this.type,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidDate,
    required this.recordedBy,
    required this.notes,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id:         id,
      uid:        map['uid']        as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      type:       PaymentTypeExt.fromString(map['type'] as String?),
      amount:     (map['amount'] as num?)?.toDouble() ?? 0.0,
      status:     PaymentStatusExt.fromString(map['status'] as String?),
      dueDate:    (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidDate:   (map['paidDate'] as Timestamp?)?.toDate(),
      recordedBy: map['recordedBy'] as String? ?? '',
      notes:      map['notes']      as String? ?? '',
      createdAt:  (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':        uid,
    'memberName': memberName,
    'type':       type.name,
    'amount':     amount,
    'status':     status.name,
    'dueDate':    Timestamp.fromDate(dueDate),
    'paidDate':   paidDate != null ? Timestamp.fromDate(paidDate!) : null,
    'recordedBy': recordedBy,
    'notes':      notes,
    'createdAt':  Timestamp.fromDate(createdAt),
  };

  PaymentModel copyWith({
    String? id, String? uid, String? memberName,
    PaymentType? type, double? amount, PaymentStatus? status,
    DateTime? dueDate, DateTime? paidDate, String? recordedBy,
    String? notes, DateTime? createdAt,
  }) => PaymentModel(
    id:         id         ?? this.id,
    uid:        uid        ?? this.uid,
    memberName: memberName ?? this.memberName,
    type:       type       ?? this.type,
    amount:     amount     ?? this.amount,
    status:     status     ?? this.status,
    dueDate:    dueDate    ?? this.dueDate,
    paidDate:   paidDate   ?? this.paidDate,
    recordedBy: recordedBy ?? this.recordedBy,
    notes:      notes      ?? this.notes,
    createdAt:  createdAt  ?? this.createdAt,
  );
}