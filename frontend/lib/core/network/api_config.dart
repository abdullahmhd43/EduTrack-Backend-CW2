import '../constants/app_constants.dart';

/// Holds the active API base URL (user can change it in Settings, useful for a physical phone).
class ApiConfig {
  String _baseUrl;
  ApiConfig([String? initial]) : _baseUrl = _normalise(initial ?? AppConfig.defaultApiBaseUrl);

  String get baseUrl => _baseUrl;
  set baseUrl(String v) => _baseUrl = _normalise(v);

  static String _normalise(String v) {
    var s = v.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static bool isValid(String v) {
    final u = Uri.tryParse(v.trim());
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
  }
}
