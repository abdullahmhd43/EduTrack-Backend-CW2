import 'package:flutter/material.dart';

import '../models/academic_event.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../models/study_session.dart';
import '../views/assignments/assignment_detail_screen.dart';
import '../views/assignments/assignment_form_screen.dart';
import '../views/auth/register_screen.dart';
import '../views/calendar/calendar_screen.dart';
import '../views/calendar/event_form_screen.dart';
import '../views/courses/course_detail_screen.dart';
import '../views/courses/course_form_screen.dart';
import '../views/notes/note_form_screen.dart';
import '../views/notes/notes_screen.dart';
import '../views/planner/session_form_screen.dart';
import '../views/profile/edit_profile_screen.dart';
import '../views/profile/profile_screen.dart';
import '../views/profile/sync_center_screen.dart';
import '../views/progress/progress_screen.dart';

/// Named routes. Form/detail screens receive the item (or its id) via `arguments`.
class AppRoutes {
  AppRoutes._();
  static const register = '/register';
  static const courseForm = '/courses/form';
  static const courseDetail = '/courses/detail';
  static const assignmentForm = '/assignments/form';
  static const assignmentDetail = '/assignments/detail';
  static const sessionForm = '/planner/form';
  static const notes = '/notes';
  static const noteForm = '/notes/form';
  static const calendar = '/calendar';
  static const eventForm = '/calendar/form';
  static const progress = '/progress';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const syncCenter = '/sync';

  static Route<dynamic>? onGenerateRoute(RouteSettings s) {
    final a = s.arguments;
    Widget? page;
    switch (s.name) {
      case register:
        page = const RegisterScreen();
      case courseForm:
        page = CourseFormScreen(course: a as Course?);
      case courseDetail:
        page = CourseDetailScreen(courseId: a as String);
      case assignmentForm:
        final args = a is AssignmentFormArgs ? a : const AssignmentFormArgs();
        page = AssignmentFormScreen(assignment: args.assignment, initialCourseId: args.courseId);
      case assignmentDetail:
        page = AssignmentDetailScreen(assignmentId: a as String);
      case sessionForm:
        final args = a is SessionFormArgs ? a : const SessionFormArgs();
        page = SessionFormScreen(session: args.session, initialDay: args.day);
      case notes:
        page = const NotesScreen();
      case noteForm:
        page = NoteFormScreen(note: a as Note?);
      case calendar:
        page = const CalendarScreen();
      case eventForm:
        final args = a is EventFormArgs ? a : const EventFormArgs();
        page = EventFormScreen(event: args.event, initialDay: args.day);
      case progress:
        page = const ProgressScreen();
      case profile:
        page = const ProfileScreen();
      case editProfile:
        page = const EditProfileScreen();
      case syncCenter:
        page = const SyncCenterScreen();
    }
    return page == null ? null : MaterialPageRoute(builder: (_) => page!, settings: s);
  }
}

class AssignmentFormArgs {
  final Assignment? assignment;
  final String? courseId;
  const AssignmentFormArgs({this.assignment, this.courseId});
}

class SessionFormArgs {
  final StudySession? session;
  final DateTime? day;
  const SessionFormArgs({this.session, this.day});
}

class EventFormArgs {
  final AcademicEvent? event;
  final DateTime? day;
  const EventFormArgs({this.event, this.day});
}
