import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/api_config.dart';

typedef TokenProvider = Future<String?> Function();

/// Thin HTTP layer: adds JWT header, JSON encoding, timeouts and maps every failure to a typed AppException.
class ApiClient {
  final ApiConfig config;
  final TokenProvider tokenProvider;
  final http.Client _http;

  /// Called when the server answers 401 so the app can log out.
  void Function()? onUnauthorized;

  ApiClient({required this.config, required this.tokenProvider, http.Client? client}) : _http = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('${config.baseUrl}$path').replace(queryParameters: query);

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final t = await tokenProvider();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = true, Map<String, String>? query}) =>
      _send(() async => _http.get(_uri(path, query), headers: await _headers(auth: auth)));

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = true}) =>
      _send(() async => _http.post(_uri(path), headers: await _headers(auth: auth), body: jsonEncode(body)));

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send(() async => _http.put(_uri(path), headers: await _headers(), body: jsonEncode(body)));

  Future<Map<String, dynamic>> delete(String path) => _send(() async => _http.delete(_uri(path), headers: await _headers()));

  /// Quick reachability probe: true only if OUR server answers (internet access alone is not enough).
  Future<bool> ping() async {
    try {
      final r = await _http.get(_uri('/health')).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw const NetworkException('The server took too long to respond.');
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    } on HandshakeException {
      throw const NetworkException('Secure connection failed.');
    }
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    Map<String, dynamic> body = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else {
          throw const ServerException('Unexpected response format from server.');
        }
      } on FormatException {
        // HTML error pages etc. are "invalid responses".
        if (res.statusCode >= 200 && res.statusCode < 300) throw const ServerException('Invalid response from server.');
      }
    }
    final code = res.statusCode;
    final msg = (body['message'] as String?) ?? 'Request failed ($code)';
    if (code >= 200 && code < 300) return body;
    switch (code) {
      case 400:
        final errs = <String, String>{};
        for (final e in (body['errors'] as List?) ?? const []) {
          if (e is Map && e['field'] != null) errs[e['field'].toString()] = e['message'].toString();
        }
        final detail = errs.isEmpty ? msg : errs.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        throw ValidationException(detail, fieldErrors: errs);
      case 401:
        onUnauthorized?.call();
        throw UnauthorizedException((body['message'] as String?) ?? 'Session expired. Please log in again.');
      case 404:
        throw NotFoundException(msg);
      case 409:
        throw ConflictException(msg, serverVersion: body['serverVersion'] as Map<String, dynamic>?);
      default:
        throw ServerException(code >= 500 ? 'Server error. Please try again later.' : msg, code);
    }
  }
}
