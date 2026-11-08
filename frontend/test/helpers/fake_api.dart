import 'package:edutrack/core/errors/app_exception.dart';
import 'package:edutrack/core/network/api_config.dart';
import 'package:edutrack/services/api/api_client.dart';
import 'package:edutrack/services/connectivity/connectivity_service.dart';

/// In-memory stand-in for the Express API with the same idempotency/conflict rules as the real server.
class FakeApi extends ApiClient {
  FakeApi() : super(config: ApiConfig('http://fake/api'), tokenProvider: () async => 'token');

  bool online = true;
  int failuresToInject = 0; // next N write calls fail with a 500
  int createCalls = 0;
  int _idSeq = 0;
  int _clock = 0;
  final Map<String, Map<String, Map<String, dynamic>>> server = {}; // path -> id -> doc

  Map<String, Map<String, dynamic>> col(String path) => server.putIfAbsent(path, () => {});

  String _tick() => DateTime.utc(2026, 1, 1).add(Duration(seconds: ++_clock)).toIso8601String();

  void _guard({bool write = false}) {
    if (!online) throw const NetworkException();
    if (write && failuresToInject > 0) {
      failuresToInject--;
      throw const ServerException('Server error. Please try again later.', 500);
    }
  }

  /// Simulates "another device" editing a record directly on the server.
  void editOnServer(String path, String id, Map<String, dynamic> changes) {
    final doc = col(path)[id]!;
    doc.addAll(changes);
    doc['updatedAt'] = _tick();
  }

  @override
  Future<bool> ping() async => online;

  @override
  Future<Map<String, dynamic>> get(String path, {bool auth = true, Map<String, String>? query}) async {
    _guard();
    return {'success': true, 'data': col(path).values.map((d) => Map<String, dynamic>.from(d)).toList()};
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    _guard(write: true);
    final existing = col(path).values.where((d) => d['clientId'] == body['clientId']);
    if (existing.isNotEmpty) return {'success': true, 'duplicate': true, 'data': Map<String, dynamic>.from(existing.first)};
    createCalls++;
    final id = 'srv${++_idSeq}';
    final now = _tick();
    final doc = {...body, 'id': id, 'createdAt': now, 'updatedAt': now};
    col(path)[id] = doc;
    return {'success': true, 'duplicate': false, 'data': Map<String, dynamic>.from(doc)};
  }

  @override
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    _guard(write: true);
    final parts = path.split('/');
    final id = parts.last;
    final base = '/${parts[1]}';
    final doc = col(base)[id];
    if (doc == null) throw const NotFoundException();
    final data = Map<String, dynamic>.from(body)..remove('baseUpdatedAt')..remove('force');
    final unchanged = data.entries.every((e) => doc[e.key] == e.value);
    if (unchanged) return {'success': true, 'data': Map<String, dynamic>.from(doc)};
    final baseUpdatedAt = body['baseUpdatedAt'] as String?;
    if (baseUpdatedAt != null && body['force'] != true && DateTime.parse(doc['updatedAt']).isAfter(DateTime.parse(baseUpdatedAt))) {
      throw ConflictException('Record was modified on the server', serverVersion: Map<String, dynamic>.from(doc));
    }
    doc.addAll(data);
    doc['updatedAt'] = _tick();
    return {'success': true, 'data': Map<String, dynamic>.from(doc)};
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    _guard(write: true);
    final parts = path.split('/');
    final removed = col('/${parts[1]}').remove(parts.last);
    if (removed == null) throw const NotFoundException();
    if (parts[1] == 'courses') {
      for (final p in ['/assignments', '/study-sessions', '/notes']) {
        col(p).removeWhere((_, d) => d['courseClientId'] == removed['clientId']);
      }
    }
    return {'success': true};
  }
}

/// Connectivity stub: no platform channels, state is controlled by the FakeApi.
class FakeConnectivity extends ConnectivityService {
  final FakeApi fake;
  FakeConnectivity(this.fake) : super(fake);

  @override
  bool get isOnline => fake.online;

  @override
  Future<bool> refresh() async => fake.online;

  @override
  Future<void> start() async {}

  @override
  void reportFailure() {}
}
