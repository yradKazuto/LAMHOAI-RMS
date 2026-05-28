// lib/core/models/user_model.dart

enum UserRole { member, admin, unknown }

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.fcmToken,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: _roleFromString(data['role'] as String?),
      fcmToken: data['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role.name, // stores 'member' | 'admin' | 'unknown'
        'fcmToken': fcmToken,
      };

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  static UserRole _roleFromString(String? value) {
    switch (value) {
      case 'member':
        return UserRole.member;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.unknown;
    }
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, role: ${role.name})';
}