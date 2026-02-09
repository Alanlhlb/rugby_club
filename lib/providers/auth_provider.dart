import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart' show AppUser, UserRole;
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isSigningUp = false;
  final Completer<void> _initCompleter = Completer<void>();

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  User? get firebaseUser => _authService.currentUser;
  Future<void> get initialized => _initCompleter.future;

  AuthProvider() {
    _init();
  }

  void _init() {
    bool firstEvent = true;
    _authService.authStateChanges.listen((user) async {
      if (user != null && !_isSigningUp) {
        await _loadUserData();
      } else if (user == null) {
        _currentUser = null;
        notifyListeners();
      }
      if (firstEvent) {
        firstEvent = false;
        if (!_initCompleter.isCompleted) _initCompleter.complete();
      }
    });
  }

  Future<void> _loadUserData() async {
    _currentUser = await _authService.getCurrentUserData();
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmail(email, password);
      await _loadUserData();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(
    String email,
    String password,
    String name, {
    UserRole role = UserRole.player,
  }) async {
    try {
      _isLoading = true;
      _isSigningUp = true;
      _error = null;
      notifyListeners();

      await _authService.signUpWithEmail(email, password, name, role: role);
      _isSigningUp = false;
      await _loadUserData();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSigningUp = false;
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUserTeam(String teamId) async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    await _authService.updateUserTeam(uid, teamId);
    await _loadUserData();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> leaveTeam() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    await _authService.updateUserProfile({'teamId': null, 'playerId': null});
    await _loadUserData();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _authService.updateUserProfile(data);
      await _loadUserData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  static String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return '找不到該帳號，請確認電郵地址是否正確';
        case 'wrong-password':
        case 'invalid-credential':
          return '密碼錯誤，請重試';
        case 'email-already-in-use':
          return '該電郵地址已被註冊';
        case 'invalid-email':
          return '電郵地址格式不正確';
        case 'weak-password':
          return '密碼強度不足，請使用至少 6 位字元';
        case 'too-many-requests':
          return '登入嘗試次數過多，請稍後再試';
        case 'network-request-failed':
          return '網絡連線失敗，請檢查網絡設定';
        case 'user-disabled':
          return '該帳號已被停用';
        default:
          return '驗證失敗：${e.message ?? e.code}';
      }
    }
    return '操作失敗，請稍後重試';
  }
}
