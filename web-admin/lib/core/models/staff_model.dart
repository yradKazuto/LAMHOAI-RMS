// core/models/staff_model.dart
// Represents Admin, Accountant, Officer accounts in the users collection

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class StaffModel {
  final String   uid;
  final String   displayName;
  final String   email;
  final UserRole role;
  final bool     isActive;
  final DateTime createdAt;

  const StaffModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory StaffModel.fromMap(Map<String, dynamic> map, String uid) {
    return StaffModel(
      uid:         uid,
      displayName: map['displayName'] as String? ?? '',
      email:       map['email']       as String? ?? '',
      role:        UserRoleExtension.fromString(map['role'] as String?),
      isActive:    map['isActive']    as bool?   ?? true,
      createdAt:   (map['createdAt']  as Timestamp?)?.toDate()
                   ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':         uid,
    'displayName': displayName,
    'email':       email,
    'role':        role.name,
    'isActive':    isActive,
    'createdAt':   Timestamp.fromDate(createdAt),
  };

  StaffModel copyWith({
    String?   uid,
    String?   displayName,
    String?   email,
    UserRole? role,
    bool?     isActive,
    DateTime? createdAt,
  }) => StaffModel(
    uid:         uid         ?? this.uid,
    displayName: displayName ?? this.displayName,
    email:       email       ?? this.email,
    role:        role        ?? this.role,
    isActive:    isActive    ?? this.isActive,
    createdAt:   createdAt   ?? this.createdAt,
  );
}