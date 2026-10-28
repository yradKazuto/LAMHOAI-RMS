// lib/core/models/ledger_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class LedgerModel {
  final String uid;
  final double annualTarget;
  final double currentBalance;
  final int year;
  final DateTime updatedAt;

  const LedgerModel({
    required this.uid,
    required this.annualTarget,
    required this.currentBalance,
    required this.year,
    required this.updatedAt,
  });

  factory LedgerModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LedgerModel(
      uid:            d['uid']            as String? ?? '',
      annualTarget:   (d['annualTarget']   as num?)?.toDouble() ?? 0.0,
      currentBalance: (d['currentBalance'] as num?)?.toDouble() ?? 0.0,
      year:           d['year']           as int? ?? DateTime.now().year,
      updatedAt:      (d['updatedAt']      as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
