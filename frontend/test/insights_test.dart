import 'package:edutrack/core/constants/app_constants.dart';
import 'package:edutrack/core/utils/date_utils.dart';
import 'package:edutrack/models/assignment.dart';
import 'package:edutrack/models/course.dart';
import 'package:edutrack/models/study_session.dart';
import 'package:edutrack/viewmodels/insights.dart';
import 'package:flutter_test/flutter_test.dart';

Course course(String id) => Course(
    localId: id, createdAt: DateTime(2026), updatedAt: DateTime(2026), name: 'C$id', code: id, startDate: DateTime(2026), endDate: DateTime(2026, 6));

Assignment assignment(String id, String courseId, DateTime due, AssignmentStatus st) => Assignment(
    localId: id, createdAt: DateTime(2026), updatedAt: DateTime(2026), courseId: courseId, title: id, dueDate: due, storedStatus: st);

StudySession session(String id, String date, String s, String e, {bool done = false}) => StudySession(
    localId: id, createdAt: DateTime(2026), updatedAt: DateTime(2026), courseId: 'c1', topic: id, date: date, startTime: s, endTime: e, completed: done);

void main() {
  final now = DateTime(2026, 11, 4, 12); // a Wednesday

  test('overdue is derived from due date + status, completed is never overdue', () {
    final past = assignment('a', 'c1', DateTime(2026, 11, 1), AssignmentStatus.inProgress);
    final pastDone = assignment('b', 'c1', DateTime(2026, 11, 1), AssignmentStatus.completed);
    final future = assignment('c', 'c1', DateTime(2026, 11, 10), AssignmentStatus.notStarted);
    expect(past.statusAt(now), AssignmentStatus.overdue);
    expect(pastDone.statusAt(now), AssignmentStatus.completed);
    expect(future.statusAt(now), AssignmentStatus.notStarted);
  });

  test('dashboard statistics are computed from the records', () {
    final r = Insights.compute(
      courses: [course('c1'), course('c2')],
      assignments: [
        assignment('a', 'c1', DateTime(2026, 11, 1), AssignmentStatus.notStarted), // overdue
        assignment('b', 'c1', DateTime(2026, 11, 9), AssignmentStatus.completed),
        assignment('c', 'c2', DateTime(2026, 11, 8), AssignmentStatus.inProgress),
        assignment('d', 'c2', DateTime(2026, 11, 20), AssignmentStatus.notStarted),
      ],
      sessions: [
        session('s1', Fmt.ymd(now), '09:00', '11:00', done: true),
        session('s2', Fmt.ymd(now.add(const Duration(days: 1))), '10:00', '11:30'),
      ],
      events: [],
      notes: [],
      now: now,
    );
    expect(r.totalCourses, 2);
    expect(r.totalAssignments, 4);
    expect(r.completed, 1);
    expect(r.pending, 3);
    expect(r.overdue, 1);
    expect(r.completionRate, 0.25);
    expect(r.upcomingDeadlines.map((a) => a.localId), ['c', 'd']); // sorted, excludes overdue & completed
    expect(r.todaySessions.length, 1);
    expect(r.weeklyPlannedMinutes, 120 + 90);
    expect(r.weeklyCompletedMinutes, 120);
    expect(r.courseProgress.firstWhere((p) => p.course.localId == 'c1').rate, 0.5);
  });

  test('empty data gives zeros (no invented numbers)', () {
    final r = Insights.compute(courses: [], assignments: [], sessions: [], events: [], notes: [], now: now);
    expect(r.totalAssignments, 0);
    expect(r.completionRate, 0);
    expect(r.weeklyPlannedMinutes, 0);
  });

  test('Fmt.minutesBetween', () {
    expect(Fmt.minutesBetween('09:00', '10:30'), 90);
    expect(Fmt.minutesBetween('10:00', '09:00'), 0);
    expect(Fmt.minutesBetween('xx', '10:00'), 0);
  });
}
