import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'entity_spec.dart';

/// Opens the SQLite database and creates the schema from the entity specs.
///
/// Common columns on every entity table:
///   localId (PK, UUID, also sent to the server as clientId), serverId (MongoDB _id, null until synced),
///   userId, syncStatus, createdAt, updatedAt, lastSyncedAt, deletedAt (tombstone),
///   serverUpdatedAt (server version we last saw: base for conflict detection), conflictData.
class AppDatabase {
  static const int version = 1;
  static const String queueTable = 'sync_queue';

  final DatabaseFactory? _factory;
  final String? _path; // inMemoryDatabasePath in tests
  Database? _db;

  AppDatabase({DatabaseFactory? factory, String? path})
      : _factory = factory,
        _path = path;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final f = _factory ?? databaseFactory;
    final path = _path ?? p.join(await f.getDatabasesPath(), 'edutrack.db');
    return f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
  }

  static String createTableSql(EntitySpec s) {
    final cols = <String>[
      'localId TEXT PRIMARY KEY',
      'serverId TEXT',
      'userId TEXT NOT NULL',
    ];
    for (final f in s.textFields) {
      if (f == s.parentField) {
        cols.add('$f TEXT${s.parentRequired ? ' NOT NULL' : ''} REFERENCES courses(localId) ON DELETE CASCADE');
      } else {
        cols.add("$f TEXT NOT NULL DEFAULT ''");
      }
    }
    for (final f in s.intFields) {
      cols.add('$f INTEGER NOT NULL DEFAULT 0');
    }
    cols.addAll([
      "syncStatus TEXT NOT NULL DEFAULT 'synced'",
      'createdAt TEXT NOT NULL',
      'updatedAt TEXT NOT NULL',
      'lastSyncedAt TEXT',
      'deletedAt TEXT',
      'serverUpdatedAt TEXT',
      'conflictData TEXT',
    ]);
    return 'CREATE TABLE ${s.table} (${cols.join(', ')})';
  }

  Future<void> _onCreate(Database db, int v) async {
    for (final s in Specs.all) {
      await db.execute(createTableSql(s));
      await db.execute('CREATE INDEX idx_${s.table}_user ON ${s.table}(userId, deletedAt)');
      await db.execute('CREATE INDEX idx_${s.table}_server ON ${s.table}(serverId)');
      await db.execute('CREATE INDEX idx_${s.table}_sync ON ${s.table}(syncStatus)');
    }
    // Pending-changes queue. UNIQUE(entity, localId) coalesces repeated edits into one operation.
    await db.execute('''
      CREATE TABLE $queueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        entity TEXT NOT NULL,
        localId TEXT NOT NULL,
        operation TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        lastError TEXT,
        createdAt TEXT NOT NULL,
        UNIQUE(entity, localId)
      )''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
