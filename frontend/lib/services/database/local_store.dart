import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import 'app_database.dart';
import 'entity_spec.dart';

typedef Row = Map<String, Object?>;

String nowIso() => DateTime.now().toUtc().toIso8601String();

class QueueItem {
  final int id;
  final String userId, entity, localId, operation;
  final int attempts;
  final String? lastError;
  const QueueItem(this.id, this.userId, this.entity, this.localId, this.operation, this.attempts, this.lastError);

  factory QueueItem.fromRow(Row r) => QueueItem(r['id'] as int, r['userId'] as String, r['entity'] as String,
      r['localId'] as String, r['operation'] as String, r['attempts'] as int, r['lastError'] as String?);
}

/// Generic SQLite data access for all synchronised entities plus the pending-changes queue.
/// Every user-facing write (create/update/delete) changes the row AND the queue in ONE transaction,
/// so the data and the "to be synced" list can never disagree.
class LocalStore {
  final AppDatabase _appDb;
  final _changes = StreamController<String>.broadcast();
  final _userWrites = StreamController<void>.broadcast();

  LocalStore(this._appDb);

  /// Emits the table name after any write (user edit or sync). ViewModels reload on it.
  Stream<String> get changes => _changes.stream;

  /// Emits only for edits made by the user (used to trigger a background sync).
  Stream<void> get userWrites => _userWrites.stream;

  Future<Database> get _db => _appDb.database;

  void notifyChanged(String table) => _changes.add(table);

  // ---------------------------------------------------------------- reads

  Future<List<Row>> all(EntitySpec s, String userId, {bool withDeleted = false}) async {
    final db = await _db;
    return db.query(s.table,
        where: withDeleted ? 'userId = ?' : 'userId = ? AND deletedAt IS NULL',
        whereArgs: [userId],
        orderBy: 'createdAt ASC');
  }

  Future<Row?> find(EntitySpec s, String localId) async {
    final db = await _db;
    final r = await db.query(s.table, where: 'localId = ?', whereArgs: [localId], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<List<Row>> conflicts(EntitySpec s, String userId) async {
    final db = await _db;
    return db.query(s.table,
        where: "userId = ? AND syncStatus = 'conflict' AND deletedAt IS NULL", whereArgs: [userId]);
  }

  // ---------------------------------------------------------------- unit-of-work writes

  Future<void> createRecord(EntitySpec s, Row row, {bool fromUser = true}) async {
    final db = await _db;
    await db.transaction((tx) async {
      await tx.insert(s.table, row);
      await _enqueue(tx, row['userId'] as String, s.table, row['localId'] as String, SyncOp.create);
    });
    _after(s.table, fromUser);
  }

  Future<void> updateRecord(EntitySpec s, String localId, Row values, {required bool hasServerId}) async {
    final db = await _db;
    final row = await find(s, localId);
    if (row == null) return;
    await db.transaction((tx) async {
      await tx.update(s.table, values, where: 'localId = ?', whereArgs: [localId]);
      await _enqueue(tx, row['userId'] as String, s.table, localId, hasServerId ? SyncOp.update : SyncOp.create);
    });
    _after(s.table, true);
  }

  /// Delete strategy: a record the server never saw is removed outright; otherwise it becomes a
  /// tombstone (deletedAt set, hidden from the UI) until the DELETE reaches the server.
  Future<void> deleteRecord(EntitySpec s, Row row) async {
    final db = await _db;
    final localId = row['localId'] as String;
    await db.transaction((tx) async {
      if (row['serverId'] == null) {
        await tx.delete(s.table, where: 'localId = ?', whereArgs: [localId]);
        await tx.delete(AppDatabase.queueTable, where: 'entity = ? AND localId = ?', whereArgs: [s.table, localId]);
      } else {
        final now = nowIso();
        await tx.update(s.table, {'deletedAt': now, 'updatedAt': now, 'syncStatus': SyncStatus.pending, 'conflictData': null},
            where: 'localId = ?', whereArgs: [localId]);
        await _enqueue(tx, row['userId'] as String, s.table, localId, SyncOp.delete);
      }
    });
    _after(s.table, true);
  }

  /// Delete a course and everything that belongs to it, as one transaction.
  Future<void> deleteCourseCascade(Row course) async {
    final localId = course['localId'] as String;
    for (final child in Specs.all.where((s) => s.parentField != null)) {
      final db = await _db;
      final rows = await db.query(child.table, where: 'courseClientId = ? AND deletedAt IS NULL', whereArgs: [localId]);
      for (final r in rows) {
        await deleteRecord(child, r);
      }
    }
    await deleteRecord(Specs.course, course);
  }

  void _after(String table, bool fromUser) {
    _changes.add(table);
    if (fromUser) _userWrites.add(null);
  }

  // ---------------------------------------------------------------- sync helpers

  Future<void> updateRaw(EntitySpec s, String localId, Row values) async {
    final db = await _db;
    await db.update(s.table, values, where: 'localId = ?', whereArgs: [localId]);
    _changes.add(s.table);
  }

  Future<void> purge(EntitySpec s, String localId) async {
    final db = await _db;
    await db.transaction((tx) async {
      await tx.delete(s.table, where: 'localId = ?', whereArgs: [localId]);
      await tx.delete(AppDatabase.queueTable, where: 'entity = ? AND localId = ?', whereArgs: [s.table, localId]);
    });
    _changes.add(s.table);
  }

  Future<void> insertRaw(EntitySpec s, Row row) async {
    final db = await _db;
    await db.insert(s.table, row);
    _changes.add(s.table);
  }

  Future<void> enqueue(String userId, EntitySpec s, String localId, String op) async {
    final db = await _db;
    await _enqueue(db, userId, s.table, localId, op);
  }

  Future<void> _enqueue(DatabaseExecutor ex, String userId, String entity, String localId, String op) async {
    final rows = await ex.query(AppDatabase.queueTable, where: 'entity = ? AND localId = ?', whereArgs: [entity, localId]);
    if (rows.isEmpty) {
      await ex.insert(AppDatabase.queueTable,
          {'userId': userId, 'entity': entity, 'localId': localId, 'operation': op, 'attempts': 0, 'createdAt': nowIso()});
      return;
    }
    final existingOp = rows.first['operation'] as String;
    // Coalescing: create+update => create; anything+delete => delete; create+delete handled by deleteRecord.
    final merged = (op == SyncOp.delete) ? SyncOp.delete : (existingOp == SyncOp.create ? SyncOp.create : op);
    await ex.update(AppDatabase.queueTable, {'operation': merged, 'attempts': 0, 'lastError': null},
        where: 'entity = ? AND localId = ?', whereArgs: [entity, localId]);
  }

  Future<List<QueueItem>> queue(String userId) async {
    final db = await _db;
    final rows = await db.query(AppDatabase.queueTable, where: 'userId = ?', whereArgs: [userId], orderBy: 'id ASC');
    return rows.map(QueueItem.fromRow).toList();
  }

  Future<void> dequeue(String entity, String localId) async {
    final db = await _db;
    await db.delete(AppDatabase.queueTable, where: 'entity = ? AND localId = ?', whereArgs: [entity, localId]);
  }

  Future<void> recordFailure(int queueId, String error) async {
    final db = await _db;
    await db.rawUpdate('UPDATE ${AppDatabase.queueTable} SET attempts = attempts + 1, lastError = ? WHERE id = ?', [error, queueId]);
  }

  /// "Retry now": give permanently failed items another chance.
  Future<void> resetAttempts(String userId) async {
    final db = await _db;
    await db.update(AppDatabase.queueTable, {'attempts': 0}, where: 'userId = ?', whereArgs: [userId]);
  }

  Future<int> pendingCount(String userId) async {
    final db = await _db;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM ${AppDatabase.queueTable} WHERE userId = ?', [userId])) ??
        0;
  }

  Future<int> failedCount(String userId) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppDatabase.queueTable} WHERE userId = ? AND attempts >= ?', [userId, AppConfig.maxSyncAttempts])) ??
        0;
  }

  Future<int> conflictCount(String userId) async {
    final db = await _db;
    var n = 0;
    for (final s in Specs.all) {
      n += Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) FROM ${s.table} WHERE userId = ? AND syncStatus = 'conflict' AND deletedAt IS NULL", [userId])) ??
          0;
    }
    return n;
  }

  Future<bool> hasDependents(String courseLocalId) async {
    final db = await _db;
    for (final s in Specs.all.where((s) => s.parentField != null)) {
      final n = Sqflite.firstIntValue(await db.rawQuery(
              "SELECT COUNT(*) FROM ${s.table} WHERE courseClientId = ? AND syncStatus != 'synced'", [courseLocalId])) ??
          0;
      if (n > 0) return true;
    }
    return false;
  }

  Future<void> transaction(Future<void> Function(Transaction tx) action) async {
    final db = await _db;
    await db.transaction(action);
  }

  void dispose() {
    _changes.close();
    _userWrites.close();
  }
}
