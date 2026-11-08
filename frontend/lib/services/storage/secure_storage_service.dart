import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/user.dart';

/// Wraps flutter_secure_storage (Android Keystore / iOS Keychain) for the JWT, cached user and API URL.
class SecureStorageService {
  static const _kToken = 'jwt_token';
  static const _kUser = 'cached_user';
  static const _kApiUrl = 'api_base_url';

  final FlutterSecureStorage _s;
  SecureStorageService([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  Future<String?> readToken() => _s.read(key: _kToken);
  Future<void> saveToken(String t) => _s.write(key: _kToken, value: t);

  Future<User?> readUser() async {
    final raw = await _s.read(key: _kUser);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(User u) => _s.write(key: _kUser, value: jsonEncode(u.toJson()));

  Future<String?> readApiUrl() => _s.read(key: _kApiUrl);
  Future<void> saveApiUrl(String v) => _s.write(key: _kApiUrl, value: v);

  /// Removes session data only (API URL is a device setting and is kept).
  Future<void> clearSession() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kUser);
  }
}
