// core/models/hoa_settings_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DuesConfig {
  final double monthly;
  final double annual;
  final double specialAssessment;
  final double penalty;

  const DuesConfig({
    required this.monthly,
    required this.annual,
    required this.specialAssessment,
    required this.penalty,
  });

  factory DuesConfig.fromMap(Map<String, dynamic> map) {
    return DuesConfig(
      monthly:           (map['monthly']           as num?)?.toDouble() ?? 0,
      annual:            (map['annual']            as num?)?.toDouble() ?? 0,
      specialAssessment: (map['specialAssessment'] as num?)?.toDouble() ?? 0,
      penalty:           (map['penalty']           as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'monthly':           monthly,
    'annual':            annual,
    'specialAssessment': specialAssessment,
    'penalty':           penalty,
  };

  DuesConfig copyWith({
    double? monthly,
    double? annual,
    double? specialAssessment,
    double? penalty,
  }) => DuesConfig(
    monthly:           monthly           ?? this.monthly,
    annual:            annual            ?? this.annual,
    specialAssessment: specialAssessment ?? this.specialAssessment,
    penalty:           penalty           ?? this.penalty,
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
      monthly:           200,
      annual:            2000,
      specialAssessment: 500,
      penalty:           50,
    ),
  );
}