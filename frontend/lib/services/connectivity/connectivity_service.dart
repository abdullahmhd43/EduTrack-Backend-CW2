import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';

/// Combines device network state (connectivity_plus) with a server ping,
/// because "has Wi-Fi" does not mean "our API is reachable".
class ConnectivityService {
  final ApiClient api;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _controller = StreamController<bool>.broadcast();
  bool _online = false;

  ConnectivityService(this.api, {Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  bool get isOnline => _online;

  /// Emits only when the online/offline state actually changes.
  Stream<bool> get onChanged => _controller.stream;

  Future<void> start() async {
    await refresh();
    _sub = _connectivity.onConnectivityChanged.listen((_) => refresh());
  }

  /// Re-evaluates connectivity. Safe to call any time (e.g. before a sync).
  Future<bool> refresh() async {
    final results = await _connectivity.checkConnectivity();
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    final reachable = hasNetwork && await api.ping();
    if (reachable != _online) {
      _online = reachable;
      _controller.add(_online);
    }
    return _online;
  }

  /// Mark offline immediately when a request fails with a network error.
  void reportFailure() {
    if (_online) {
      _online = false;
      _controller.add(false);
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
