import 'package:edutrack/core/constants/app_constants.dart';
import 'package:edutrack/services/database/entity_spec.dart';
import 'package:edutrack/services/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv.create());
  // in-memory SQLite is shared per process; close it so every test starts empty
  tearDown(() => env.db.close());

  test('SQLite: create offline -> stored locally as pending and queued', () async {
    env.api.online = false;
    final c = await env.courses.create(env.courseFields());
    expect(c.syncStatus, SyncStatus.pending);
    expect((await env.courses.getAll()).length, 1);
    expect(await env.store.pendingCount('u1'), 1);
    await env.sync.syncNow();
    expect(env.sync.state, SyncState.offline);
    expect(env.api.col('/courses'), isEmpty); // nothing reached the server
  });

  test('Reconnect: pending create is pushed, status becomes synced, queue emptied', () async {
    env.api.online = false;
    final c = await env.courses.create(env.courseFields());
    env.api.online = true;
    await env.sync.syncNow();
    expect(env.api.col('/courses').length, 1);
    final local = (await env.courses.getById(c.localId))!;
    expect(local.syncStatus, SyncStatus.synced);
    expect(local.serverId, isNotNull);
    expect(await env.store.pendingCount('u1'), 0);
    expect(env.sync.state, SyncState.synced);
  });

  test('Duplicate prevention: syncing repeatedly / retried POST never duplicates', () async {
    await env.courses.create(env.courseFields());
    await env.sync.syncNow();
    await env.sync.syncNow();
    await env.sync.syncNow();
    expect(env.api.col('/courses').length, 1);
    expect(env.api.createCalls, 1);
    expect((await env.courses.getAll()).length, 1);
  });

  test('Offline update of a synced record is pushed as an update', () async {
    final c = await env.courses.create(env.courseFields());
    await env.sync.syncNow();
    env.api.online = false;
    await env.courses.update(c.localId, env.courseFields('Renamed'));
    expect((await env.courses.getById(c.localId))!.name, 'Renamed');
    expect((await env.courses.getById(c.localId))!.syncStatus, SyncStatus.pending);
    env.api.online = true;
    await env.sync.syncNow();
    expect(env.api.col('/courses').values.first['name'], 'Renamed');
    expect((await env.courses.getById(c.localId))!.syncStatus, SyncStatus.synced);
  });

  test('Offline delete uses a tombstone, hidden immediately, removed on server after reconnect', () async {
    final c = await env.courses.create(env.courseFields());
    await env.sync.syncNow();
    env.api.online = false;
    await env.courses.delete(c.localId);
    expect(await env.courses.getAll(), isEmpty); // hidden from the UI
    final raw = await env.store.find(Specs.course, c.localId);
    expect(raw!['deletedAt'], isNotNull); // tombstone still in SQLite
    env.api.online = true;
    await env.sync.syncNow();
    expect(env.api.col('/courses'), isEmpty);
    expect(await env.store.find(Specs.course, c.localId), isNull);
  });

  test('Deleting a never-synced record just removes it (nothing to tell the server)', () async {
    env.api.online = false;
    final c = await env.courses.create(env.courseFields());
    await env.courses.delete(c.localId);
    expect(await env.store.pendingCount('u1'), 0);
    expect(await env.store.find(Specs.course, c.localId), isNull);
  });

  test('Restart: data and pending queue survive closing and reopening the database', () async {
    final path = TestEnv.tempDbPath();
    var e1 = TestEnv.create(path: path);
    e1.api.online = false;
    await e1.courses.create(e1.courseFields('Persisted'));
    await e1.db.close();

    final e2 = TestEnv.create(path: path); // "app restarted", still offline
    e2.api.online = false;
    expect((await e2.courses.getAll()).single.name, 'Persisted');
    expect(await e2.store.pendingCount('u1'), 1);
    e2.api.online = true;
    await e2.sync.syncNow();
    expect(e2.api.col('/courses').length, 1);
  });

  test('Failed sync is recoverable: error recorded, retried successfully later', () async {
    await env.courses.create(env.courseFields());
    env.api.failuresToInject = 1;
    await env.sync.syncNow();
    expect(env.sync.state, SyncState.failed);
    expect(await env.store.pendingCount('u1'), 1);
    await env.sync.syncNow(retryFailed: true);
    expect(env.sync.state, SyncState.synced);
    expect(env.api.col('/courses').length, 1);
  });

  test('Conflict: server copy changed -> local edit is NOT silently overwritten; keepMine resolves', () async {
    final c = await env.courses.create(env.courseFields());
    await env.sync.syncNow();
    final serverId = (await env.courses.getById(c.localId))!.serverId!;
    env.api.online = false;
    await env.courses.update(c.localId, env.courseFields('Local edit'));
    env.api.editOnServer('/courses', serverId, {'name': 'Edited elsewhere'});
    env.api.online = true;
    await env.sync.syncNow();

    expect(env.api.col('/courses')[serverId]!['name'], 'Edited elsewhere'); // server value untouched
    final conflicts = await env.sync.loadConflicts();
    expect(conflicts.length, 1);
    expect(conflicts.first.diffs.any((d) => d.field == 'name'), isTrue);

    await env.sync.keepMine(conflicts.first);
    await env.sync.syncNow();
    expect(env.api.col('/courses')[serverId]!['name'], 'Local edit');
    expect(await env.sync.loadConflicts(), isEmpty);
  });

  test('Conflict: useServer discards the local edit', () async {
    final c = await env.courses.create(env.courseFields());
    await env.sync.syncNow();
    final serverId = (await env.courses.getById(c.localId))!.serverId!;
    env.api.online = false;
    await env.courses.update(c.localId, env.courseFields('Local edit'));
    env.api.editOnServer('/courses', serverId, {'name': 'Server wins'});
    env.api.online = true;
    await env.sync.syncNow();
    await env.sync.useServer((await env.sync.loadConflicts()).first);
    expect((await env.courses.getById(c.localId))!.name, 'Server wins');
    expect((await env.courses.getById(c.localId))!.syncStatus, SyncStatus.synced);
  });

  test('Pull: records created on the server appear locally; records deleted elsewhere disappear', () async {
    env.api.col('/courses')['srvX'] = {
      'id': 'srvX', 'clientId': 'client-x-0001', 'name': 'From server', 'code': 'SRV1', 'lecturer': '', 'description': '',
      'startDate': '2026-01-01T00:00:00.000Z', 'endDate': '2026-06-01T00:00:00.000Z',
      'createdAt': '2026-01-01T00:00:00.000Z', 'updatedAt': '2026-01-01T00:00:00.000Z',
    };
    await env.sync.syncNow();
    expect((await env.courses.getAll()).single.name, 'From server');
    env.api.col('/courses').clear(); // deleted on another device
    await env.sync.syncNow();
    expect(await env.courses.getAll(), isEmpty);
  });

  test('Dependency order: assignment created offline for an offline course syncs after its course', () async {
    env.api.online = false;
    final c = await env.courses.create(env.courseFields());
    await env.assignments.create(env.assignmentFields(c.localId));
    env.api.online = true;
    await env.sync.syncNow();
    expect(env.api.col('/courses').length, 1);
    expect(env.api.col('/assignments').length, 1);
    expect(env.api.col('/assignments').values.first['courseClientId'], c.localId);
  });

  test('Deleting a course cascades locally to its assignments', () async {
    final c = await env.courses.create(env.courseFields());
    await env.assignments.create(env.assignmentFields(c.localId));
    await env.sync.syncNow();
    await env.courses.delete(c.localId);
    expect(await env.assignments.getAll(), isEmpty);
    await env.sync.syncNow();
    expect(env.api.col('/courses'), isEmpty);
    expect(env.api.col('/assignments'), isEmpty);
  });

  test('Users only see their own local data', () async {
    await env.courses.create(env.courseFields());
    env.user.userId = 'u2';
    expect(await env.courses.getAll(), isEmpty);
  });

  test('Assignment model keeps due date and derived overdue status', () async {
    final c = await env.courses.create(env.courseFields());
    final a = await env.assignments.create(env.assignmentFields(c.localId, due: DateTime.now().subtract(const Duration(days: 2))));
    expect(a.status, AssignmentStatus.overdue);
  });
}
