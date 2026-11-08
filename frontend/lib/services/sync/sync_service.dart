import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../api/api_client.dart';
import '../connectivity/connectivity_service.dart';
import '../database/entity_spec.dart';
import '../database/local_store.dart';
import '../database/user_context.dart';

enum SyncState { offline, online, syncing, failed, synced }

/// One differing field in a sync conflict.
class FieldDiff {
  final String field;
  final String mine;
  final String server;
  const FieldDiff(this.field, this.mine, this.server);
}

class ConflictInfo {
  final EntitySpec spec;
  final String localId;
  final String label;
  final bool deletedOnServer;
  final List<FieldDiff> diffs;
  const ConflictInfo(this.spec, this.localId, this.label, this.deletedOnServer, this.diffs);
}

/// Offline-first synchronisation engine.
///
///  PUSH  local pending queue -> server (creates/updates in parent-first order, then deletes child-first)
///        - create: POST with clientId = localId  (server de-duplicates => idempotent, safe to retry)
///        - update: PUT with baseUpdatedAt        (server answers 409 if its copy is newer => conflict, never overwritten)
///        - delete: DELETE                        (404 counts as success => idempotent)
///  PULL  server -> local reconcile (inserts, updates for clean rows, removal of rows deleted elsewhere)
class SyncService extends ChangeNotifier {
  final LocalStore store;
  final ApiClient api;
  final ConnectivityService connectivity;
  final UserContext user;

  SyncState _state = SyncState.offline;
  int pendingCount = 0, conflictCount = 0, failedCount = 0;
  String? lastError;
  DateTime? lastSyncedAt;
  bool _running = false;
  Future<void>? _inflight;
  bool _again = false;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<void>? _writeSub;
  Timer? _debounce;
  Timer? _periodic;

  SyncService({required this.store, required this.api, required this.connectivity, required this.user});

  SyncState get state => _running ? SyncState.syncing : _state;
  bool get isOnline => connectivity.isOnline;

  Future<void> start() async {
    await connectivity.start();
    _state = connectivity.isOnline ? SyncState.online : SyncState.offline;
    _connSub = connectivity.onChanged.listen((online) {
      if (online) {
        syncNow();
      } else {
        _state = SyncState.offline;
        notifyListeners();
      }
    });
    _writeSub = store.userWrites.listen((_) {
      _refreshCounts();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 700), syncNow);
    });
    // Retry mechanism: periodically retry while there is unsynchronised work.
    _periodic = Timer.periodic(const Duration(seconds: 45), (_) {
      if (user.userId != null && (pendingCount > 0 || !connectivity.isOnline)) syncNow();
    });
    notifyListeners();
  }

  Future<void> _refreshCounts() async {
    final uid = user.userId;
    if (uid == null) {
      pendingCount = conflictCount = failedCount = 0;
    } else {
      pendingCount = await store.pendingCount(uid);
      conflictCount = await store.conflictCount(uid);
      failedCount = await store.failedCount(uid);
    }
    notifyListeners();
  }

  /// Run a full push+pull cycle if the server is reachable. Safe to call repeatedly.
  ///
  /// If a cycle is already running, the caller waits for it and one more cycle is run afterwards,
  /// so a change made during a sync is never left waiting for the periodic retry.
  Future<void> syncNow({bool retryFailed = false}) {
    if (user.userId == null) return Future.value();
    final running = _inflight;
    if (running != null) {
      _again = true;
      return running;
    }
    final f = _runLoop(retryFailed).whenComplete(() => _inflight = null);
    _inflight = f;
    return f;
  }

  Future<void> _runLoop(bool retryFailed) async {
    var retry = retryFailed;
    do {
      _again = false;
      await _cycle(retry);
      retry = false;
    } while (_again);
  }

  Future<void> _cycle(bool retryFailed) async {
    final uid = user.userId;
    if (uid == null) return;
    _running = true;
    notifyListeners();
    var hadFailures = false;
    try {
      if (retryFailed) await store.resetAttempts(uid);
      final online = await connectivity.refresh();
      if (!online) {
        _state = SyncState.offline;
        return;
      }
      final failures = await _push(uid);
      await _pull(uid);
      hadFailures = failures > 0;
      lastSyncedAt = DateTime.now();
      lastError = hadFailures ? 'Some changes could not be synced. They will be retried.' : null;
      _state = hadFailures ? SyncState.failed : SyncState.synced;
    } on NetworkException {
      connectivity.reportFailure();
      _state = SyncState.offline;
    } on UnauthorizedException catch (e) {
      lastError = e.message;
      _state = SyncState.failed;
    } on AppException catch (e) {
      lastError = e.message;
      _state = SyncState.failed;
    } catch (e) {
      lastError = 'Unexpected sync error';
      _state = SyncState.failed;
    } finally {
      _running = false;
      await _refreshCounts();
    }
  }

  // ------------------------------------------------------------------ PUSH

  /// Returns the number of queue items that failed (conflicts are not failures: they need the user).
  Future<int> _push(String uid) async {
    var failures = 0;
    final queue = await store.queue(uid);
    for (final spec in Specs.all) {
      for (final item in queue.where((q) => q.entity == spec.table && q.operation != SyncOp.delete)) {
        if (item.attempts >= AppConfig.maxSyncAttempts) {
          failures++;
          continue;
        }
        if (!await _pushUpsert(uid, spec, item)) failures++;
      }
    }
    for (final spec in Specs.all.reversed) {
      for (final item in queue.where((q) => q.entity == spec.table && q.operation == SyncOp.delete)) {
        if (item.attempts >= AppConfig.maxSyncAttempts) {
          failures++;
          continue;
        }
        if (!await _pushDelete(spec, item)) failures++;
      }
    }
    return failures;
  }

  Future<bool> _pushUpsert(String uid, EntitySpec spec, QueueItem item) async {
    final row = await store.find(spec, item.localId);
    if (row == null || row['deletedAt'] != null) {
      await store.dequeue(spec.table, item.localId);
      return true;
    }
    if (row['syncStatus'] == SyncStatus.conflict) return true;

    final pushedAt = row['updatedAt'] as String;
    final serverId = row['serverId'] as String?;
    final body = spec.toApiBody(row);
    try {
      final Map<String, dynamic> res;
      if (serverId == null) {
        res = await api.post(spec.apiPath, {...body, 'clientId': row['localId']});
      } else {
        final base = row['serverUpdatedAt'];
        res = await api.put('${spec.apiPath}/$serverId', {...body, if (base != null) 'baseUpdatedAt': base});
      }
      await _applyPushed(spec, item, pushedAt, res['data'] as Map<String, dynamic>, duplicate: res['duplicate'] == true);
      return true;
    } on ConflictException catch (e) {
      await _markConflict(spec, item.localId, e.serverVersion ?? const {});
      return true;
    } on NotFoundException catch (e) {
      if (serverId == null) {
        await store.recordFailure(item.id, e.message);
        return false;
      }
      await _markConflict(spec, item.localId, const {'deleted': true});
      return true;
    } on NetworkException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } on AppException catch (e) {
      await store.recordFailure(item.id, e.message);
      return false;
    }
  }

  Future<void> _applyPushed(EntitySpec spec, QueueItem item, String pushedAt, Map<String, dynamic> doc, {required bool duplicate}) async {
    final current = await store.find(spec, item.localId);
    if (current == null) return;
    final values = <String, Object?>{
      'serverId': doc['id'],
      'serverUpdatedAt': doc['updatedAt'],
      'lastSyncedAt': nowIso(),
      'conflictData': null,
    };
    // If the user edited the record while the request was in flight, or the server answered with an older
    // duplicate (a retried create), keep it pending: it is re-sent as an update on the next cycle.
    final stillDirty = current['updatedAt'] != pushedAt || duplicate;
    if (stillDirty) {
      await store.updateRaw(spec, item.localId, values);
      await store.enqueue(item.userId, spec, item.localId, SyncOp.update);
    } else {
      await store.updateRaw(spec, item.localId, {...values, 'syncStatus': SyncStatus.synced});
      await store.dequeue(spec.table, item.localId);
    }
  }

  Future<void> _markConflict(EntitySpec spec, String localId, Map<String, dynamic> serverDoc) async {
    await store.updateRaw(spec, localId, {'syncStatus': SyncStatus.conflict, 'conflictData': jsonEncode(serverDoc)});
    await store.dequeue(spec.table, localId); // stop retrying until the user decides
  }

  Future<bool> _pushDelete(EntitySpec spec, QueueItem item) async {
    final row = await store.find(spec, item.localId);
    if (row == null) {
      await store.dequeue(spec.table, item.localId);
      return true;
    }
    final serverId = row['serverId'] as String?;
    if (serverId == null) {
      await store.purge(spec, item.localId);
      return true;
    }
    try {
      await api.delete('${spec.apiPath}/$serverId');
      await store.purge(spec, item.localId);
      return true;
    } on NotFoundException {
      await store.purge(spec, item.localId); // already gone: deleting twice is fine (idempotent)
      return true;
    } on NetworkException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } on AppException catch (e) {
      await store.recordFailure(item.id, e.message);
      return false;
    }
  }

  // ------------------------------------------------------------------ PULL

  Future<void> _pull(String uid) async {
    final now = nowIso();
    final docs = <EntitySpec, List<Map<String, dynamic>>>{};
    for (final spec in Specs.all) {
      final res = await api.get(spec.apiPath);
      docs[spec] = ((res['data'] as List?) ?? const []).cast<Map<String, dynamic>>();
    }
    for (final spec in Specs.all) {
      await _reconcileUpserts(uid, spec, docs[spec]!, now);
    }
    for (final spec in Specs.all.reversed) {
      await _reconcileRemovals(uid, spec, docs[spec]!);
    }
  }

  Future<void> _reconcileUpserts(String uid, EntitySpec spec, List<Map<String, dynamic>> docs, String now) async {
    final local = {for (final r in await store.all(spec, uid, withDeleted: true)) r['localId'] as String: r};
    for (final doc in docs) {
      final clientId = doc['clientId'] as String?;
      if (clientId == null) continue;
      final row = local[clientId];
      final fields = spec.fieldsFromApi(doc);
      if (row == null) {
        try {
          await store.insertRaw(spec, {
            'localId': clientId,
            'serverId': doc['id'],
            'userId': uid,
            ...fields,
            'syncStatus': SyncStatus.synced,
            'createdAt': doc['createdAt'],
            'updatedAt': doc['updatedAt'],
            'lastSyncedAt': now,
            'deletedAt': null,
            'serverUpdatedAt': doc['updatedAt'],
            'conflictData': null,
          });
        } catch (_) {
          // e.g. parent missing locally: skipped, will be retried on the next pull
        }
      } else if (row['syncStatus'] == SyncStatus.synced && row['deletedAt'] == null) {
        if (row['serverUpdatedAt'] != doc['updatedAt'] || row['serverId'] == null) {
          await store.updateRaw(spec, clientId, {
            ...fields,
            'serverId': doc['id'],
            'updatedAt': doc['updatedAt'],
            'serverUpdatedAt': doc['updatedAt'],
            'lastSyncedAt': now,
          });
        }
      }
      // pending / conflict / tombstoned rows are never overwritten by a pull.
    }
  }

  Future<void> _reconcileRemovals(String uid, EntitySpec spec, List<Map<String, dynamic>> docs) async {
    final serverIds = docs.map((d) => d['id']).toSet();
    for (final row in await store.all(spec, uid)) {
      final sid = row['serverId'];
      if (sid == null || row['syncStatus'] != SyncStatus.synced || serverIds.contains(sid)) continue;
      final localId = row['localId'] as String;
      // Deleted on another device. Do not destroy unsynced local work that depends on it: re-create instead.
      if (spec == Specs.course && await store.hasDependents(localId)) {
        await store.updateRaw(spec, localId, {'serverId': null, 'serverUpdatedAt': null, 'syncStatus': SyncStatus.pending});
        await store.enqueue(uid, spec, localId, SyncOp.create);
      } else {
        await store.purge(spec, localId);
      }
    }
  }

  // ------------------------------------------------------------------ CONFLICTS

  Future<List<ConflictInfo>> loadConflicts() async {
    final uid = user.userId;
    if (uid == null) return const [];
    final out = <ConflictInfo>[];
    for (final spec in Specs.all) {
      for (final row in await store.conflicts(spec, uid)) {
        final server = _decode(row['conflictData']);
        final deleted = server['deleted'] == true;
        final diffs = <FieldDiff>[];
        if (!deleted) {
          final serverFields = spec.fieldsFromApi(server);
          for (final f in spec.fields) {
            final a = '${row[f] ?? ''}', b = '${serverFields[f] ?? ''}';
            if (a != b) diffs.add(FieldDiff(f, a, b));
          }
        }
        out.add(ConflictInfo(spec, row['localId'] as String, '${row[spec.labelField] ?? ''}', deleted, diffs));
      }
    }
    return out;
  }

  Map<String, dynamic> _decode(Object? raw) {
    try {
      return (jsonDecode(raw as String) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// User chose "keep my version": it is re-sent with the server's latest version as the new base.
  Future<void> keepMine(ConflictInfo c) async {
    final uid = user.requireUserId;
    final row = await store.find(c.spec, c.localId);
    if (row == null) return;
    if (c.deletedOnServer) {
      await store.updateRaw(c.spec, c.localId,
          {'serverId': null, 'serverUpdatedAt': null, 'syncStatus': SyncStatus.pending, 'conflictData': null});
      await store.enqueue(uid, c.spec, c.localId, SyncOp.create);
    } else {
      final server = _decode(row['conflictData']);
      await store.updateRaw(c.spec, c.localId,
          {'serverUpdatedAt': server['updatedAt'], 'syncStatus': SyncStatus.pending, 'conflictData': null});
      await store.enqueue(uid, c.spec, c.localId, SyncOp.update);
    }
    await _refreshCounts();
    unawaited(syncNow());
  }

  /// User chose "use server version": local edit is discarded.
  Future<void> useServer(ConflictInfo c) async {
    final row = await store.find(c.spec, c.localId);
    if (row == null) return;
    if (c.deletedOnServer) {
      await store.purge(c.spec, c.localId);
    } else {
      final server = _decode(row['conflictData']);
      await store.updateRaw(c.spec, c.localId, {
        ...c.spec.fieldsFromApi(server),
        'serverId': server['id'],
        'updatedAt': server['updatedAt'],
        'serverUpdatedAt': server['updatedAt'],
        'lastSyncedAt': nowIso(),
        'syncStatus': SyncStatus.synced,
        'conflictData': null,
      });
    }
    await _refreshCounts();
  }

  /// Called by AuthViewModel when the signed-in user changes.
  Future<void> onSessionChanged() async {
    await _refreshCounts();
    if (user.userId != null) unawaited(syncNow());
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _writeSub?.cancel();
    _debounce?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
