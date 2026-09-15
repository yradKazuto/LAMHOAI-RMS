// core/models/hoa_settings_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DuesConfig {
  // NOTE: `monthly` removed — the monthly rate lives in the
  // `monthly_dues_rates` collection (see MonthlyRateModel /
  // RateHistoryService) instead of a single fixed value here.
  final double annual;
  final double specialAssessment;
  final double penalty;

  // Days after a dues/membershipFee record's dueDate before the flat
  // `penalty` amount gets added to it (see
  // FirestoreService.applyOverduePenalties). Defaults to 5 for any
  // settings doc saved before this field existed.
  final int penaltyGraceDays;

  const DuesConfig({
    required this.annual,
    required this.specialAssessment,
    required this.penalty,
    this.penaltyGraceDays = 5,
  });

  factory DuesConfig.fromMap(Map<String, dynamic> map) {
    return DuesConfig(
      annual:            (map['annual']            as num?)?.toDouble() ?? 0,
      specialAssessment: (map['specialAssessment'] as num?)?.toDouble() ?? 0,
      penalty:           (map['penalty']           as num?)?.toDouble() ?? 0,
      penaltyGraceDays:  (map['penaltyGraceDays']  as num?)?.toInt()    ?? 5,
    );
  }

  Map<String, dynamic> toMap() => {
    'annual':            annual,
    'specialAssessment': specialAssessment,
    'penalty':           penalty,
    'penaltyGraceDays':  penaltyGraceDays,
  };

  DuesConfig copyWith({
    double? annual,
    double? specialAssessment,
    double? penalty,
    int?    penaltyGraceDays,
  }) => DuesConfig(
    annual:            annual            ?? this.annual,
    specialAssessment: specialAssessment ?? this.specialAssessment,
    penalty:           penalty           ?? this.penalty,
    penaltyGraceDays:  penaltyGraceDays  ?? this.penaltyGraceDays,
  );
}

class HoaSettingsModel {
  final String     name;
  final String     address;
  final String     contactNumber;
  final String     email;
  final String     president;
  final DuesConfig dues;
  final DateTime?  updatedAt;

  const HoaSettingsModel({
    required this.name,
    required this.address,
    required this.contactNumber,
    required this.email,
    required this.president,
    required this.dues,
    this.updatedAt,
  });

  factory HoaSettingsModel.fromMap(
      Map<String, dynamic> map) {
    return HoaSettingsModel(
      name:          map['name']          as String? ?? '',
      address:       map['address']       as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      email:         map['email']         as String? ?? '',
      president:     map['president']     as String? ?? '',
      dues:          DuesConfig.fromMap(
          (map['dues'] as Map<String, dynamic>?) ?? {}),
      updatedAt:     (map['updatedAt'] as Timestamp?)
                         ?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':          name,
    'address':       address,
    'contactNumber': contactNumber,
    'email':         email,
    'president':     president,
    'dues':          dues.toMap(),
    'updatedAt':     Timestamp.fromDate(DateTime.now()),
  };

  static HoaSettingsModel get defaults => HoaSettingsModel(
    name:          'La Milagrosa Homeowners Association',
    address:       '',
    contactNumber: '',
    email:         '',
    president:     '',
    dues:          const DuesConfig(
      annual:            2000,
      specialAssessment: 500,
      penalty:           50,
      penaltyGraceDays:  5,
    ),
  );
}