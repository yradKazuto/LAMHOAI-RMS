// core/models/monthly_rate_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyRateModel {
  final String   id;
  final double   amount;
  final DateTime effectiveStart; // first day of the month this rate applies from
  final String   setBy;
  final DateTime createdAt;

  const MonthlyRateModel({
    required this.id,
    required this.amount,
    required this.effectiveStart,
    required this.setBy,
    required this.createdAt,
  });

  factory MonthlyRateModel.fromMap(Map<String, dynamic> map, String id) {
    return MonthlyRateModel(
      id:             id,
      amount:         (map['amount'] as num?)?.toDouble() ?? 0.0,
      effectiveStart: (map['effectiveStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      setBy:          map['setBy'] as String? ?? '',
      createdAt:      (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'amount':         amount,
    'effectiveStart': Timestamp.fromDate(effectiveStart),
    'setBy':          setBy,
    'createdAt':      Timestamp.fromDate(createdAt),
  };
}