import 'dart:io';

import 'package:edutrack/core/constants/app_constants.dart';
import 'package:edutrack/models/academic_event.dart';
import 'package:edutrack/models/assignment.dart';
import 'package:edutrack/models/course.dart';
import 'package:edutrack/models/note.dart';
import 'package:edutrack/models/study_session.dart';
import 'package:edutrack/repositories/entity_repository.dart';
import 'package:edutrack/services/database/app_database.dart';
import 'package:edutrack/services/database/entity_spec.dart';
import 'package:edutrack/services/database/local_store.dart';
import 'package:edutrack/services/database/user_context.dart';
import 'package:edutrack/services/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_api.dart';

/// Wires the real LocalStore/repositories/SyncService to a real (ffi) SQLite database and the FakeApi.
class TestEnv {
  final AppDatabase db;
  final LocalStore store;
  final UserContext user;
  final FakeApi api;
  final SyncService sync;
  final EntityRepository<Course> courses;
  final EntityRepository<Assignment> assignments;
  final EntityRepository<StudySession> sessions;
  final EntityRepository<Note> notes;
  final EntityRepository<AcademicEvent> events;

  TestEnv._(this.db, this.store, this.user, this.api, this.sync, this.courses, this.assignments, this.sessions, this.notes, this.events);

  /// [path] defaults to an in-memory database; pass a file path to simulate an app restart.
  factory TestEnv.create({String? path, FakeApi? api, String userId = 'u1'}) {
    sqfliteFfiInit();
    final db = AppDatabase(factory: databaseFactoryFfi, path: path ?? inMemoryDatabasePath);
    final store = LocalStore(db);
    final user = UserContext()..userId = userId;
    final fake = api ?? FakeApi();
    final sync = SyncService(store: store, api: fake, connectivity: FakeConnectivity(fake), user: user);
    return TestEnv._(
      db,
      store,
      user,
      fake,
      sync,
      EntityRepository<Course>(spec: Specs.course, store: store, user: user, fromRow: Course.fromRow),
      EntityRepository<Assignment>(spec: Specs.assignment, store: store, user: user, fromRow: Assignment.fromRow),
      EntityRepository<StudySession>(spec: Specs.studySession, store: store, user: user, fromRow: StudySession.fromRow),
      EntityRepository<Note>(spec: Specs.note, store: store, user: user, fromRow: Note.fromRow),
      EntityRepository<AcademicEvent>(spec: Specs.event, store: store, user: user, fromRow: AcademicEvent.fromRow),
    );
  }

  static String tempDbPath() => '${Directory.systemTemp.createTempSync('edutrack_test').path}/test.db';

  Map<String, Object?> courseFields([String name = 'Mobile App Dev', String code = 'CI6330']) => Course.fields(
      name: name, code: code, lecturer: 'Dr X', startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 6, 1));

  Map<String, Object?> assignmentFields(String courseId, {String title = 'Coursework 2', DateTime? due}) => Assignment.fields(
      courseId: courseId,
      title: title,
      dueDate: due ?? DateTime.now().add(const Duration(days: 5)),
      priority: _p,
      status: _s);

  static const _p = Priority.medium;
  static const _s = AssignmentStatus.notStarted;
}
