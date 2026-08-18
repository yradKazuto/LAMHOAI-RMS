// lib/core/providers/auth_provider.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../services/onesignal_service.dart';

import '../models/user_model.dart';
import '../services/fcm_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth      _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String?    _errorMessage;

  AuthStatus get status       => _status;
  UserModel? get user         => _user;
  String?    get errorMessage => _errorMessage;
  bool get isAuthenticated    => _status == AuthStatus.authenticated;

  AuthProvider({
    FirebaseAuth?      auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  })  : _auth      = auth      ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance {
    _init();
  }

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  void _init() {
    // Set a fallback timer — if auth state doesn't resolve in 15 seconds
    // on slow internet, force unauthenticated so the app never stays on splash
    Future.delayed(const Duration(seconds: 15), () {
      if (_status == AuthStatus.initial || _status == AuthStatus.loading) {
        debugPrint('Auth state timeout — forcing unauthenticated');
        _user = null;
        _setStatus(AuthStatus.unauthenticated);
      }
    });

    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    _setStatus(AuthStatus.loading);
    try {
      // Timeout Firestore fetch — slow internet should not block forever
      final userModel = await _fetchUserModel(firebaseUser.uid)
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timed out. Please check your internet.');
        },
      );
      _user = userModel;

      // FCM — best effort, never block auth
      // AFTER:
      // Push notifications — best effort, never block auth
      try {
        if (!kIsWeb) {
          // Mobile (Android/iOS) — OneSignal
          await OneSignalService.instance
              .login(firebaseUser.uid)
              .timeout(const Duration(seconds: 5));
        } else {
          // Web — still FCM (OneSignal web not set up yet)
          const vapidKey = 'BCZQo4FNWMRofNJqJJ_Z8NrHyq7IVigdQ8WJd6ua_hR9LM73-2ysxdp_5oStC0swAAs6YmCszWMxYFOZT96lEPg';
          if (vapidKey != 'YOUR_VAPID_KEY_HERE') {
            await FCMService.instance
                .saveTokenToFirestore(firebaseUser.uid, vapidKey: vapidKey)
                .timeout(const Duration(seconds: 5));
          }
        }
      } catch (e) {
        debugPrint('Push token setup skipped: $e');
      }

      _setStatus(AuthStatus.authenticated);
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(AuthStatus.error);
    }
  }

  // ── Auth actions ──────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    _setStatus(AuthStatus.loading);
    try {
      await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setStatus(AuthStatus.error);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await OneSignalService.instance.logout();
    }
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setStatus(AuthStatus.error);
      rethrow;
    }
  }

  // ── Firestore helpers ─────────────────────────────────────────────────────

  Future<UserModel> _fetchUserModel(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('User profile not found. Contact your HOA admin.');
    }
    return UserModel.fromFirestore(doc.data()!, uid);
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) _setStatus(AuthStatus.unauthenticated);
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your HOA admin.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Sign-in failed ($code). Please try again.';
    }
  }
}