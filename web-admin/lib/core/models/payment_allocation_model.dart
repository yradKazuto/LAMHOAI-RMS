// core/models/payment_allocation_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentAllocationModel {
  final String id;
  final String transactionId;
  final String memberUid;
  final String obligationId;
  final double allocatedPrincipal;
  final double allocatedPenalty;
  final double allocatedAmount; // = principal + penalty
  final DateTime allocatedAt;

  const PaymentAllocationModel({
    required this.id,
    required this.transactionId,
    required this.memberUid,
    required this.obligationId,
    required this.allocatedPrincipal,
    required this.allocatedPenalty,
    required this.allocatedAmount,
    required this.allocatedAt,
  });

  factory PaymentAllocationModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentAllocationModel(
      id: id,
      transactionId: map['transactionId'] as String? ?? '',
      memberUid: map['memberUid'] as String? ?? '',
      obligationId: map['obligationId'] as String? ?? '',
      allocatedPrincipal: (map['allocatedPrincipal'] as num?)?.toDouble() ?? 0.0,
      allocatedPenalty: (map['allocatedPenalty'] as num?)?.toDouble() ?? 0.0,
      allocatedAmount: (map['allocatedAmount'] as num?)?.toDouble() ?? 0.0,
      allocatedAt: (map['allocatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'transactionId': transactionId,
    'memberUid': memberUid,
    'obligationId': obligationId,
    'allocatedPrincipal': allocatedPrincipal,
    'allocatedPenalty': allocatedPenalty,
    'allocatedAmount': allocatedAmount,
    'allocatedAt': Timestamp.fromDate(allocatedAt),
  };
}
