// core/models/payment_transaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus { posted, voided }

class PaymentTransactionModel {
  final String id;
  final String memberUid;
  final String memberName;
  final double amount;
  final String paymentMethod; // 'cash' for current version; extensible
  final String? referenceNumber; // optional manual reference
  final DateTime paymentDate;
  final String recordedBy;
  final String notes;
  final DateTime createdAt;
  final TransactionStatus status;
  final double unappliedCredit;

  const PaymentTransactionModel({
    required this.id,
    required this.memberUid,
    required this.memberName,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    required this.paymentDate,
    required this.recordedBy,
    required this.notes,
    required this.createdAt,
    required this.status,
    required this.unappliedCredit,
  });

  factory PaymentTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentTransactionModel(
      id: id,
      memberUid: map['memberUid'] as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      referenceNumber: map['referenceNumber'] as String?,
      paymentDate: (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedBy: map['recordedBy'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] == 'voided' ? TransactionStatus.voided : TransactionStatus.posted,
      unappliedCredit: (map['unappliedCredit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'memberUid': memberUid,
    'memberName': memberName,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'referenceNumber': referenceNumber,
    'paymentDate': Timestamp.fromDate(paymentDate),
    'recordedBy': recordedBy,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status.name,
    'unappliedCredit': unappliedCredit,
  };
}
