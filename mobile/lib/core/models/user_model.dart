// lib/core/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/enum_utils.dart';

enum UserRole { member, admin, accountant, officer, unknown }

const Map<UserRole, String> _userRoleLabels = {
  UserRole.member: 'Member',
  UserRole.admin: 'Admin',
  UserRole.accountant: 'Accountant',
  UserRole.officer: 'Officer',
  UserRole.unknown: 'Unknown',
};

const Map<String, UserRole> _userRoleLookup = {
  'member': UserRole.member,
  'admin': UserRole.admin,
  'accountant': UserRole.accountant,
  'officer': UserRole.officer,
};

extension UserRoleExtension on UserRole {
  String get label => enumLabel(this, _userRoleLabels);

  static UserRole fromString(String? value) =>
      enumFromString(value, _userRoleLookup, defaultValue: UserRole.unknown);
}

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
  final bool?   isActive;
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
    this.isActive,
    this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid:           uid,
      email:         data['email']         as String? ?? '',
      displayName:   data['displayName']   as String? ?? '',
      role:          UserRoleExtension.fromString(data['role'] as String?),
      fcmToken:      data['fcmToken']      as String?,
      lotNumber:     data['lotNumber']     as String?,
      phase:         data['phase']         as String?,
      status:        data['status']        as String?,
      address:       data['address']       as String?,
      contactNumber: data['contactNumber'] as String?,
      isActive:      data['isActive']      as bool?,
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
        'isActive':      isActive,
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
    bool?     isActive,
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
      isActive:      isActive      ?? this.isActive,
      createdAt:     createdAt     ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, role: ${role.name}, isActive: $isActive)';
}