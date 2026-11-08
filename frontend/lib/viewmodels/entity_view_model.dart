import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/sync_model.dart';
import '../repositories/entity_repository.dart';

/// Base ViewModel: holds the list state for one entity, reloads automatically when the local
/// database changes (user edit or sync), and exposes create/update/delete that return an error
/// message (null = success) so Views never contain business logic.
abstract class EntityViewModel<T extends SyncModel> extends ChangeNotifier {
  final EntityRepository<T> repo;
  List<T> items = [];
  bool loading = false;
  String? error;
  StreamSubscription<String>? _sub;
  bool _disposed = false;

  EntityViewModel(this.repo) {
    _sub = repo.changes.listen((_) => load(silent: true));
  }

  Future<void> load({bool silent = false}) async {
    if (repo.user.userId == null) {
      items = [];
      _notify();
      return;
    }
    if (!silent) {
      loading = true;
      _notify();
    }
    try {
      items = await repo.getAll();
      error = null;
    } catch (e) {
      error = describeError(e);
    }
    loading = false;
    _notify();
  }

  Future<String?> create(Map<String, Object?> fields) => _run(() => repo.create(fields));
  Future<String?> update(String localId, Map<String, Object?> fields) => _run(() => repo.update(localId, fields));
  Future<String?> delete(String localId) => _run(() => repo.delete(localId));

  Future<String?> _run(Future<Object?> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return describeError(e);
    }
  }

  static String describeError(Object e) => e is AppException ? e.message : 'Something went wrong. Please try again.';

  T? byId(String? id) {
    if (id == null) return null;
    for (final i in items) {
      if (i.localId == id) return i;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Subclasses call this after changing filter state.
  @protected
  void refreshView() => _notify();

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
