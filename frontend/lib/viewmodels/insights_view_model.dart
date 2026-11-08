import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/academic_event.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../models/study_session.dart';
import '../repositories/entity_repository.dart';
import '../services/database/local_store.dart';
import 'insights.dart';

/// Feeds the Dashboard and Learning Progress screens from real records. Recomputes whenever any table changes.
class InsightsViewModel extends ChangeNotifier {
  final EntityRepository<Course> courses;
  final EntityRepository<Assignment> assignments;
  final EntityRepository<StudySession> sessions;
  final EntityRepository<AcademicEvent> events;
  final EntityRepository<Note> notes;
  final LocalStore store;

  Insights insights = Insights.empty;
  bool loading = false;
  StreamSubscription<String>? _sub;
  Timer? _debounce;
  bool _disposed = false;

  InsightsViewModel({required this.courses, required this.assignments, required this.sessions, required this.events, required this.notes, required this.store}) {
    _sub = store.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () => load(silent: true));
    });
  }

  Future<void> load({bool silent = false}) async {
    if (courses.user.userId == null) {
      insights = Insights.empty;
      if (!_disposed) notifyListeners();
      return;
    }
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      insights = Insights.compute(
        courses: await courses.getAll(),
        assignments: await assignments.getAll(),
        sessions: await sessions.getAll(),
        events: await events.getAll(),
        notes: await notes.getAll(),
        now: DateTime.now(),
      );
    } catch (_) {
      // keep previous insights on failure
    }
    loading = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
