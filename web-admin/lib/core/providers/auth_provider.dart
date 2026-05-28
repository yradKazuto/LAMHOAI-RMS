// core/providers/auth_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _init();
  }

  // ── State ──────────────────────────────────────────────────────────────────
  AuthStatus _status = AuthStatus.initial;
  UserModel? _userModel;
  String? _errorMessage;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<UserModel?>? _userSub;

  // ── Getters ────────────────────────────────────────────────────────────────
  AuthStatus get status => _status;
  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  UserRole get role => _userModel?.role ?? UserRole.unknown;
  bool get isAdmin => role == UserRole.admin;
  bool get isAccountant => role == UserRole.accountant;
  bool get isOfficer => role == UserRole.officer;

  // ── Init — listen to Firebase auth state ──────────────────────────────────
  void _init() {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _userSub?.cancel();
      _userModel = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Subscribe to live user doc updates
    _userSub?.cancel();
    _userSub = _authService.userModelStream(firebaseUser.uid).listen(
      (model) {
        if (model == null || !model.isActive) {
          _authService.signOut();
          return;
        }
        _userModel = model;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        _status = AuthStatus.error;
        _errorMessage = 'Failed to load user profile.';
        notifyListeners();
      },
    );
  }

  // ── Sign in ────────────────────────────────────────────────────────────────
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // _onAuthStateChanged will handle status update
      return true;
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = AuthService.mapFirebaseError(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    // _onAuthStateChanged handles cleanup
  }

  // ── Permission helper ──────────────────────────────────────────────────────
  bool hasAccess(List<UserRole> allowedRoles) {
    return allowedRoles.contains(role);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}