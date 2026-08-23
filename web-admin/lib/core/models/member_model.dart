// core/models/member_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberStatus { active, inactive, delinquent }

extension MemberStatusExt on MemberStatus {
  String get label {
    switch (this) {
      case MemberStatus.active:     return 'Active';
      case MemberStatus.inactive:   return 'Inactive';
      case MemberStatus.delinquent: return 'Delinquent';
    }
  }

  static MemberStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'active':      return MemberStatus.active;
      case 'inactive':    return MemberStatus.inactive;
      case 'delinquent':  return MemberStatus.delinquent;
      default:            return MemberStatus.active;
    }
  }
}

class MemberModel {
  final String uid;
  final String name;           // maps to 'displayName' in Firestore
  final String email;
  final String role;
  final String lotNumber;
  final String phase;
  final MemberStatus status;
  final String contactNumber;
  final String address;
  final String photoUrl;       // profile photo — empty string if none set
  final DateTime createdAt;

  const MemberModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.lotNumber,
    required this.phase,
    required this.status,
    required this.contactNumber,
    required this.address,
    this.photoUrl = '',
    required this.createdAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map, String uid) {
    return MemberModel(
      uid:           uid,
      // reads 'displayName' to stay compatible with mobile app
      // falls back to 'name' if displayName is missing
      name:          map['displayName'] as String?
                     ?? map['name'] as String?
                     ?? '',
      email:         map['email']         as String? ?? '',
      role:          map['role']          as String? ?? 'member',
      lotNumber:     map['lotNumber']     as String? ?? '',
      phase:         map['phase']         as String? ?? '',
      status:        MemberStatusExt.fromString(map['status'] as String?),
      contactNumber: map['contactNumber'] as String? ?? '',
      address:       map['address']       as String? ?? '',
      photoUrl:      map['photoUrl']      as String? ?? '',
      createdAt:     (map['createdAt'] as Timestamp?)?.toDate()
                     ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':           uid,
    'displayName':   name,     // saves as 'displayName' — matches mobile
    'email':         email,
    'role':          role,
    'lotNumber':     lotNumber,
    'phase':         phase,
    'status':        status.name,
    'contactNumber': contactNumber,
    'address':       address,
    'photoUrl':      photoUrl,
    'createdAt':     Timestamp.fromDate(createdAt),
  };

  MemberModel copyWith({
    String? uid, String? name, String? email, String? role,
    String? lotNumber, String? phase, MemberStatus? status,
    String? contactNumber, String? address, String? photoUrl,
    DateTime? createdAt,
  }) => MemberModel(
    uid:           uid           ?? this.uid,
    name:          name          ?? this.name,
    email:         email         ?? this.email,
    role:          role          ?? this.role,
    lotNumber:     lotNumber     ?? this.lotNumber,
    phase:         phase         ?? this.phase,
    status:        status        ?? this.status,
    contactNumber: contactNumber ?? this.contactNumber,
    address:       address       ?? this.address,
    photoUrl:      photoUrl      ?? this.photoUrl,
    createdAt:     createdAt     ?? this.createdAt,
  );
}