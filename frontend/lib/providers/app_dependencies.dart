import 'dart:async';

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/network/api_config.dart';
import '../models/academic_event.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../models/study_session.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/entity_repository.dart';
import '../services/api/api_client.dart';
import '../services/connectivity/connectivity_service.dart';
import '../services/database/app_database.dart';
import '../services/database/entity_spec.dart';
import '../services/database/local_store.dart';
import '../services/database/user_context.dart';
import '../services/storage/secure_storage_service.dart';
import '../services/sync/sync_service.dart';
import '../viewmodels/assignment_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/course_view_model.dart';
import '../viewmodels/event_view_model.dart';
import '../viewmodels/insights_view_model.dart';
import '../viewmodels/note_view_model.dart';
import '../viewmodels/study_session_view_model.dart';

/// Composition root: builds every service/repository/ViewModel once and wires them together
/// (manual dependency injection), then exposes them to the widget tree through Provider.
class AppDependencies {
  late final ApiConfig apiConfig;
  late final SecureStorageService storage;
  late final ApiClient api;
  late final ConnectivityService connectivity;
  late final AppDatabase database;
  late final LocalStore store;
  late final UserContext userContext;
  late final SyncService sync;
  late final AuthRepository authRepo;
  late final AuthViewModel auth;
  late final CourseViewModel courses;
  late final AssignmentViewModel assignments;
  late final StudySessionViewModel sessions;
  late final NoteViewModel notes;
  late final EventViewModel events;
  late final InsightsViewModel insights;

  AppDependencies() {
    apiConfig = ApiConfig();
    storage = SecureStorageService();
    api = ApiClient(config: apiConfig, tokenProvider: () => storage.readToken());
    connectivity = ConnectivityService(api);
    database = AppDatabase();
    store = LocalStore(database);
    userContext = UserContext();
    sync = SyncService(store: store, api: api, connectivity: connectivity, user: userContext);
    authRepo = AuthRepository(api, storage);
    auth = AuthViewModel(repo: authRepo, storage: storage, apiConfig: apiConfig);

    final courseRepo = EntityRepository<Course>(spec: Specs.course, store: store, user: userContext, fromRow: Course.fromRow);
    final assignmentRepo = EntityRepository<Assignment>(spec: Specs.assignment, store: store, user: userContext, fromRow: Assignment.fromRow);
    final sessionRepo = EntityRepository<StudySession>(spec: Specs.studySession, store: store, user: userContext, fromRow: StudySession.fromRow);
    final noteRepo = EntityRepository<Note>(spec: Specs.note, store: store, user: userContext, fromRow: Note.fromRow);
    final eventRepo = EntityRepository<AcademicEvent>(spec: Specs.event, store: store, user: userContext, fromRow: AcademicEvent.fromRow);

    courses = CourseViewModel(courseRepo);
    assignments = AssignmentViewModel(assignmentRepo);
    sessions = StudySessionViewModel(sessionRepo);
    notes = NoteViewModel(noteRepo);
    events = EventViewModel(eventRepo);
    insights = InsightsViewModel(
        courses: courseRepo, assignments: assignmentRepo, sessions: sessionRepo, events: eventRepo, notes: noteRepo, store: store);

    // A 401 from the server means the token is no longer valid -> sign out.
    api.onUnauthorized = () => auth.logout();
    auth.onSessionChanged = _onSessionChanged;
  }

  Future<void> _onSessionChanged(User? user) async {
    userContext.userId = user?.id;
    await Future.wait([courses.load(), assignments.load(), sessions.load(), notes.load(), events.load(), insights.load()]);
    await sync.onSessionChanged();
  }

  Future<void> start() async {
    // Offline-first: never block start-up on the network. Connectivity/sync start in the background,
    // the session is restored immediately from secure storage + SQLite.
    unawaited(sync.start());
    await auth.restore();
  }

  List<SingleChildWidget> get providers => [
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider<SyncService>.value(value: sync),
        ChangeNotifierProvider<CourseViewModel>.value(value: courses),
        ChangeNotifierProvider<AssignmentViewModel>.value(value: assignments),
        ChangeNotifierProvider<StudySessionViewModel>.value(value: sessions),
        ChangeNotifierProvider<NoteViewModel>.value(value: notes),
        ChangeNotifierProvider<EventViewModel>.value(value: events),
        ChangeNotifierProvider<InsightsViewModel>.value(value: insights),
        Provider<ApiConfig>.value(value: apiConfig),
      ];
}
