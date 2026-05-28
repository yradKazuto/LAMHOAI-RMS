// core/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  // ── Auth state stream ──────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  // ── Sign in ────────────────────────────────────────────────────────────────
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Fetch user doc from Firestore ──────────────────────────────────────────
  Future<UserModel?> fetchUserModel(String uid) async {
    final doc =
        await _firestore.collection(_usersCollection).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, uid);
  }

  // ── Stream user doc (live updates) ────────────────────────────────────────
  Stream<UserModel?> userModelStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(snap.data()!, uid);
    });
  }

  // ── Create user (Admin use only) ──────────────────────────────────────────
  Future<void> createUserRecord(UserModel user) async {
    await _firestore
        .collection(_usersCollection)
        .doc(user.uid)
        .set(user.toMap());
  }

  // ── Update user role (Admin use only) ─────────────────────────────────────
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .update({'role': role.name});
  }

  // ── Map Firebase error codes to readable messages ─────────────────────────
  static String mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}