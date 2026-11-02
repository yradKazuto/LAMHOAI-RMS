import 'package:cloud_firestore/cloud_firestore.dart';

class RateTier {
  final String label;
  final double threshold;
  final double rate;

  const RateTier({required this.label, required this.threshold, required this.rate});

  Map<String, dynamic> toMap() => {'label': label, 'threshold': threshold, 'rate': rate};
  factory RateTier.fromMap(Map<String, dynamic> map) => RateTier(
    label: map['label'],
    threshold: map['threshold'].toDouble(),
    rate: map['rate'].toDouble(),
  );
}

class RateScheduleModel {
  final String id;
  final int year;
  final bool isActive;
  final List<RateTier> tiers;

  const RateScheduleModel({required this.id, required this.year, required this.isActive, required this.tiers});

  Map<String, dynamic> toMap() => {
    'year': year,
    'isActive': isActive,
    'tiers': tiers.map((t) => t.toMap()).toList(),
  };

  factory RateScheduleModel.fromMap(String id, Map<String, dynamic> map) => RateScheduleModel(
    id: id,
    year: map['year'],
    isActive: map['isActive'],
    tiers: (map['tiers'] as List).map((t) => RateTier.fromMap(t)).toList(),
  );
}
