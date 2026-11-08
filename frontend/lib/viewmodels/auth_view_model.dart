import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/network/api_config.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/storage/secure_storage_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository repo;
  final SecureStorageService storage;
  final ApiConfig apiConfig;

  /// Wired by AppDependencies: reacts to login/logout (scope repositories to the user, load data, sync).
  Future<void> Function(User? user)? onSessionChanged;

  AuthStatus status = AuthStatus.unknown;
  User? user;
  bool loading = false;
  String? error;
  Map<String, String> fieldErrors = {};

  AuthViewModel({required this.repo, required this.storage, required this.apiConfig});

  /// Restore the session from secure storage. Works fully offline: the cached user is enough.
  Future<void> restore() async {
    final savedUrl = await storage.readApiUrl();
    if (savedUrl != null && ApiConfig.isValid(savedUrl)) apiConfig.baseUrl = savedUrl;
    final token = await repo.readToken();
    final cached = await repo.cachedUser();
    if (token != null && cached != null) {
      user = cached;
      status = AuthStatus.authenticated;
      await onSessionChanged?.call(user);
      notifyListeners();
      _verifyInBackground();
    } else {
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _verifyInBackground() async {
    try {
      user = await repo.fetchMe();
      notifyListeners();
    } on UnauthorizedException {
      await logout();
    } catch (_) {
      // offline or server down: keep working with the cached profile
    }
  }

  Future<bool> login(String email, String password) => _auth(() => repo.login(email, password));

  Future<bool> register({required String name, required String email, required String password, String studentId = '', String program = ''}) =>
      _auth(() => repo.register(name: name, email: email, password: password, studentId: studentId, program: program));

  Future<bool> _auth(Future<User> Function() action) async {
    loading = true;
    error = null;
    fieldErrors = {};
    notifyListeners();
    try {
      user = await action();
      status = AuthStatus.authenticated;
      await onSessionChanged?.call(user);
      loading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (e) {
      error = e.message;
      fieldErrors = e.fieldErrors;
    } on AppException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unexpected error. Please try again.';
    }
    loading = false;
    notifyListeners();
    return false;
  }

  Future<String?> updateProfile({required String name, required String studentId, required String program}) async {
    try {
      user = await repo.updateProfile(name: name, studentId: studentId, program: program);
      notifyListeners();
      return null;
    } on AppException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update profile.';
    }
  }

  Future<void> logout() async {
    if (status != AuthStatus.authenticated) return;
    await repo.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    error = null;
    await onSessionChanged?.call(null);
    notifyListeners();
  }

  Future<void> setApiUrl(String url) async {
    apiConfig.baseUrl = url;
    await storage.saveApiUrl(apiConfig.baseUrl);
    notifyListeners();
  }

  void clearError() {
    error = null;
    fieldErrors = {};
    notifyListeners();
  }
}
