import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../models/sync_model.dart';
import '../services/database/entity_spec.dart';
import '../services/database/local_store.dart';
import '../services/database/user_context.dart';

/// Repository for one entity type. The UI layer only ever talks to this class, never to SQLite or HTTP:
/// all reads/writes hit the local database first (offline-first) and the SyncService reconciles with the server.
class EntityRepository<T extends SyncModel> {
  final EntitySpec spec;
  final LocalStore store;
  final UserContext user;
  final T Function(Map<String, Object?> row) fromRow;
  static const _uuid = Uuid();

  EntityRepository({required this.spec, required this.store, required this.user, required this.fromRow});

  Stream<String> get changes => store.changes.where((t) => t == spec.table);

  Future<List<T>> getAll() async => (await store.all(spec, user.requireUserId)).map(fromRow).toList();

  Future<T?> getById(String localId) async {
    final r = await store.find(spec, localId);
    return (r == null || r['deletedAt'] != null) ? null : fromRow(r);
  }

  /// Create locally (works offline). localId doubles as the server's clientId => idempotent sync.
  Future<T> create(Map<String, Object?> fields) async {
    final now = nowIso();
    final row = <String, Object?>{
      'localId': _uuid.v4(),
      'serverId': null,
      'userId': user.requireUserId,
      ...fields,
      'syncStatus': SyncStatus.pending,
      'createdAt': now,
      'updatedAt': now,
      'lastSyncedAt': null,
      'deletedAt': null,
      'serverUpdatedAt': null,
      'conflictData': null,
    };
    await store.createRecord(spec, row);
    return fromRow(row);
  }

  Future<void> update(String localId, Map<String, Object?> fields) async {
    final row = await store.find(spec, localId);
    if (row == null || row['deletedAt'] != null) throw const AppException('This record no longer exists.');
    if (row['syncStatus'] == SyncStatus.conflict) {
      throw const AppException('Resolve the sync conflict in Sync Center before editing this item.');
    }
    await store.updateRecord(
      spec,
      localId,
      {...fields, 'updatedAt': nowIso(), 'syncStatus': SyncStatus.pending},
      hasServerId: row['serverId'] != null,
    );
  }

  Future<void> delete(String localId) async {
    final row = await store.find(spec, localId);
    if (row == null) return;
    if (spec == Specs.course) {
      await store.deleteCourseCascade(row);
    } else {
      await store.deleteRecord(spec, row);
    }
  }
}
