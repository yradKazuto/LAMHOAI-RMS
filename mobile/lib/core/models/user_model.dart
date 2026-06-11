// lib/core/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { member, admin, unknown }

class UserModel {
  final String  uid;
  final String  email;
  final String  displayName;
  final UserRole role;
  final String? fcmToken;
  final String? lotNumber;
  final String? phase;
  final String? status;
  final String? address;
  final String? contactNumber;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.fcmToken,
    this.lotNumber,
    this.phase,
    this.status,
    this.address,
    this.contactNumber,
    this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid:           uid,
      email:         data['email']         as String? ?? '',
      displayName:   data['displayName']   as String? ?? '',
      role:          _roleFromString(data['role'] as String?),
      fcmToken:      data['fcmToken']      as String?,
      lotNumber:     data['lotNumber']     as String?,
      phase:         data['phase']         as String?,
      status:        data['status']        as String?,
      address:       data['address']       as String?,
      contactNumber: data['contactNumber'] as String?,
      createdAt:     (data['createdAt']    as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid':           uid,
        'email':         email,
        'displayName':   displayName,
        'role':          role.name,
        'fcmToken':      fcmToken,
        'lotNumber':     lotNumber,
        'phase':         phase,
        'status':        status,
        'address':       address,
        'contactNumber': contactNumber,
        'createdAt':     createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : null,
      };

  UserModel copyWith({
    String?   uid,
    String?   email,
    String?   displayName,
    UserRole? role,
    String?   fcmToken,
    String?   lotNumber,
    String?   phase,
    String?   status,
    String?   address,
    String?   contactNumber,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid:           uid           ?? this.uid,
      email:         email         ?? this.email,
      displayName:   displayName   ?? this.displayName,
      role:          role          ?? this.role,
      fcmToken:      fcmToken      ?? this.fcmToken,
      lotNumber:     lotNumber     ?? this.lotNumber,
      phase:         phase         ?? this.phase,
      status:        status        ?? this.status,
      address:       address       ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      createdAt:     createdAt     ?? this.createdAt,
    );
  }

  static UserRole _roleFromString(String? value) {
    switch (value) {
      case 'member': return UserRole.member;
      case 'admin':  return UserRole.admin;
      default:       return UserRole.unknown;
    }
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, role: ${role.name})';
}