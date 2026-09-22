// core/models/dues_config_history_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// A snapshot of DuesConfig (annual, specialAssessment, penalty,
/// penaltyGraceDays) at the moment it changed. One record is written
/// whenever a save from the Dues Configuration dialog actually changes at
/// least one of those four values — NOT on every save, and NOT for the
/// monthly rate (that has its own history via MonthlyRateModel /
/// RateHistoryService).
///
/// [createdAt] is when this configuration took effect. There is no
/// separate "end date" — a record's effective range runs from its
/// createdAt until the next record's createdAt (or now, for the most
/// recent one). Collection: `dues_config_history`.
class DuesConfigHistoryModel {
  final String id;
  final double annual;
  final double specialAssessment;
  final double penalty;
  final int penaltyGraceDays;
  final String changedBy;
  final DateTime createdAt;

  const DuesConfigHistoryModel({
    required this.id,
    required this.annual,
    required this.specialAssessment,
    required this.penalty,
    required this.penaltyGraceDays,
    required this.changedBy,
    required this.createdAt,
  });

  factory DuesConfigHistoryModel.fromMap(
      Map<String, dynamic> map, String id) {
    return DuesConfigHistoryModel(
      id: id,
      annual: (map['annual'] as num?)?.toDouble() ?? 0,
      specialAssessment:
          (map['specialAssessment'] as num?)?.toDouble() ?? 0,
      penalty: (map['penalty'] as num?)?.toDouble() ?? 0,
      penaltyGraceDays: (map['penaltyGraceDays'] as num?)?.toInt() ?? 5,
      changedBy: map['changedBy'] as String? ?? '',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'annual': annual,
    'specialAssessment': specialAssessment,
    'penalty': penalty,
    'penaltyGraceDays': penaltyGraceDays,
    'changedBy': changedBy,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}