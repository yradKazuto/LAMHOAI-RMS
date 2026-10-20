// core/models/user_model.dart

import '../../../core/utils/enum_utils.dart';

enum UserRole { admin, accountant, officer, unknown }

const Map<UserRole, String> _userRoleLabels = {
  UserRole.admin: 'Admin',
  UserRole.accountant: 'Accountant',
  UserRole.officer: 'Officer',
  UserRole.unknown: 'Unknown',
};

const Map<String, UserRole> _userRoleLookup = {
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
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: UserRoleExtension.fromString(map['role'] as String?),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}