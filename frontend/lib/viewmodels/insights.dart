import '../core/utils/date_utils.dart';
import '../models/academic_event.dart';
import '../models/assignment.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../models/study_session.dart';
import '../core/constants/app_constants.dart';

class CourseProgress {
  final Course course;
  final int total, completed;
  const CourseProgress(this.course, this.total, this.completed);
  double get rate => total == 0 ? 0 : completed / total;
}

class Activity {
  final String title, kind;
  final DateTime at;
  const Activity(this.title, this.kind, this.at);
}

/// Pure statistics computed from real database records (no hard-coded numbers). Easy to unit test.
class Insights {
  final int totalCourses, totalAssignments, completed, pending, overdue, totalNotes;
  final double completionRate;
  final List<Assignment> upcomingDeadlines;
  final List<StudySession> todaySessions;
  final List<AcademicEvent> upcomingEvents;
  final List<int> plannedMinutesByDay; // Mon..Sun
  final List<int> completedMinutesByDay;
  final List<StudySession> sessionHistory;
  final List<CourseProgress> courseProgress;
  final List<Activity> recent;

  const Insights({
    required this.totalCourses,
    required this.totalAssignments,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.totalNotes,
    required this.completionRate,
    required this.upcomingDeadlines,
    required this.todaySessions,
    required this.upcomingEvents,
    required this.plannedMinutesByDay,
    required this.completedMinutesByDay,
    required this.sessionHistory,
    required this.courseProgress,
    required this.recent,
  });

  int get weeklyPlannedMinutes => plannedMinutesByDay.fold(0, (a, b) => a + b);
  int get weeklyCompletedMinutes => completedMinutesByDay.fold(0, (a, b) => a + b);

  static const empty = Insights(
    totalCourses: 0, totalAssignments: 0, completed: 0, pending: 0, overdue: 0, totalNotes: 0, completionRate: 0,
    upcomingDeadlines: [], todaySessions: [], upcomingEvents: [], plannedMinutesByDay: [0, 0, 0, 0, 0, 0, 0],
    completedMinutesByDay: [0, 0, 0, 0, 0, 0, 0], sessionHistory: [], courseProgress: [], recent: [],
  );

  static Insights compute({
    required List<Course> courses,
    required List<Assignment> assignments,
    required List<StudySession> sessions,
    required List<AcademicEvent> events,
    required List<Note> notes,
    required DateTime now,
  }) {
    final done = assignments.where((a) => a.isCompleted).length;
    final overdue = assignments.where((a) => a.statusAt(now) == AssignmentStatus.overdue).length;

    final upcoming = assignments.where((a) => !a.isCompleted && !a.dueDate.isBefore(now)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final todayKey = Fmt.ymd(now);
    final today = sessions.where((s) => s.date == todayKey).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    final monday = Fmt.startOfWeek(now);
    final planned = List<int>.filled(7, 0);
    final doneMin = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final key = Fmt.ymd(monday.add(Duration(days: i)));
      for (final s in sessions.where((s) => s.date == key)) {
        planned[i] += s.minutes;
        if (s.completed) doneMin[i] += s.minutes;
      }
    }

    final history = sessions.where((s) => s.completed).toList()
      ..sort((a, b) => '${b.date} ${b.startTime}'.compareTo('${a.date} ${a.startTime}'));

    final progress = courses.map((c) {
      final mine = assignments.where((a) => a.courseId == c.localId).toList();
      return CourseProgress(c, mine.length, mine.where((a) => a.isCompleted).length);
    }).toList();

    final nextEvents = events.where((e) => !e.startsAt.isBefore(Fmt.dayOnly(now))).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final recent = <Activity>[
      for (final c in courses) Activity(c.name, 'Course', c.updatedAt),
      for (final a in assignments) Activity(a.title, 'Assignment', a.updatedAt),
      for (final s in sessions) Activity(s.topic, 'Study session', s.updatedAt),
      for (final n in notes) Activity(n.title, 'Note', n.updatedAt),
      for (final e in events) Activity(e.title, 'Event', e.updatedAt),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return Insights(
      totalCourses: courses.length,
      totalAssignments: assignments.length,
      completed: done,
      pending: assignments.length - done,
      overdue: overdue,
      totalNotes: notes.length,
      completionRate: assignments.isEmpty ? 0 : done / assignments.length,
      upcomingDeadlines: upcoming.take(5).toList(),
      todaySessions: today,
      upcomingEvents: nextEvents.take(3).toList(),
      plannedMinutesByDay: planned,
      completedMinutesByDay: doneMin,
      sessionHistory: history.take(20).toList(),
      courseProgress: progress,
      recent: recent.take(6).toList(),
    );
  }
}
