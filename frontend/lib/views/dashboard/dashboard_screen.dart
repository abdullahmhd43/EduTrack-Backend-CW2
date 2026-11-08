import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../services/sync/sync_service.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/insights_view_model.dart';
import '../../viewmodels/study_session_view_model.dart';
import '../../viewmodels/assignment_view_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/custom/assignment_card.dart';
import '../../widgets/custom/event_card.dart';
import '../../widgets/custom/progress_ring.dart';
import '../../widgets/custom/session_card.dart';
import '../../widgets/custom/stat_card.dart';
import '../shell/shell_nav.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    final vm = context.watch<InsightsViewModel>();
    final courses = context.watch<CourseViewModel>();
    final sessionsVm = context.read<StudySessionViewModel>();
    final assignmentsVm = context.read<AssignmentViewModel>();
    final i = vm.insights;
    final t = Theme.of(context);
    final s = t.colorScheme;
    final nav = context.read<ShellNav>();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final firstName = (user?.name ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduTrack'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: s.primaryContainer,
              child: Text(
                  (firstName.isEmpty ? '?' : firstName[0]).toUpperCase(),
                  style: TextStyle(
                      color: s.onPrimaryContainer,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<SyncService>().syncNow(retryFailed: true);
          await vm.load(silent: true);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ---- welcome + profile summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                    colors: [s.primary, s.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$greeting,',
                            style: const TextStyle(color: Colors.white70)),
                        Text(firstName.isEmpty ? 'Student' : firstName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        if ((user?.program ?? '').isNotEmpty)
                          Text(user!.program,
                              style: const TextStyle(color: Colors.white)),
                        if ((user?.studentId ?? '').isNotEmpty)
                          Text('ID: ${user!.studentId}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(Fmt.pretty(DateTime.now()),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                ),
                ProgressRing(
                  value: i.completionRate,
                  size: 84,
                  strokeWidth: 9,
                  color: Colors.white,
                  center: Text('${(i.completionRate * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ---- statistics from real records
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                    icon: Icons.menu_book,
                    label: 'Courses',
                    value: '${i.totalCourses}',
                    color: s.primary,
                    onTap: () => nav.go(1)),
                StatCard(
                    icon: Icons.assignment,
                    label: 'Assignments',
                    value: '${i.totalAssignments}',
                    color: AppColors.info,
                    onTap: () => nav.go(2)),
                StatCard(
                    icon: Icons.pending_actions,
                    label:
                        'Pending${i.overdue > 0 ? ' (${i.overdue} overdue)' : ''}',
                    value: '${i.pending}',
                    color: AppColors.warning,
                    onTap: () => nav.go(2)),
                StatCard(
                    icon: Icons.task_alt,
                    label: 'Completed',
                    value: '${i.completed}',
                    color: AppColors.success,
                    onTap: () => nav.go(2)),
              ],
            ),

            // ---- quick actions
            const SectionHeader('Quick actions'),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _Quick(
                    Icons.add_circle_outline,
                    'Course',
                    () =>
                        Navigator.of(context).pushNamed(AppRoutes.courseForm)),
                _Quick(Icons.assignment_add, 'Assignment', () {
                  if (courses.items.isEmpty) {
                    Navigator.of(context).pushNamed(AppRoutes.courseForm);
                  } else {
                    Navigator.of(context).pushNamed(AppRoutes.assignmentForm);
                  }
                }),
                _Quick(
                    Icons.timer_outlined,
                    'Study session',
                    () =>
                        Navigator.of(context).pushNamed(AppRoutes.sessionForm)),
                _Quick(Icons.note_add_outlined, 'Note',
                    () => Navigator.of(context).pushNamed(AppRoutes.noteForm)),
                _Quick(Icons.event_available_outlined, 'Event',
                    () => Navigator.of(context).pushNamed(AppRoutes.eventForm)),
              ]),
            ),

            // ---- upcoming deadlines
            SectionHeader('Upcoming deadlines',
                actionLabel: 'See all', onAction: () => nav.go(2)),
            if (i.upcomingDeadlines.isEmpty)
              const _EmptyLine(
                  Icons.celebration_outlined, 'No upcoming deadlines')
            else
              for (final a in i.upcomingDeadlines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AssignmentCard(
                    assignment: a,
                    courseName: courses.nameOf(a.courseId),
                    onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.assignmentDetail,
                        arguments: a.localId),
                    onToggleDone: () => assignmentsVm.changeStatus(
                        a,
                        a.isCompleted
                            ? AssignmentStatus.notStarted
                            : AssignmentStatus.completed),
                  ),
                ),

            // ---- today's study sessions
            SectionHeader("Today's study sessions",
                actionLabel: 'Planner', onAction: () => nav.go(3)),
            if (i.todaySessions.isEmpty)
              const _EmptyLine(
                  Icons.self_improvement, 'Nothing planned for today')
            else
              for (final ss in i.todaySessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SessionCard(
                    session: ss,
                    courseName: courses.nameOf(ss.courseId),
                    onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.sessionForm,
                        arguments: SessionFormArgs(session: ss)),
                    onToggle: () => sessionsVm.toggleCompleted(ss),
                  ),
                ),

            // ---- weekly overview
            const SectionHeader('This week'),
            AppCard(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.progress),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Study time',
                              style: t.textTheme.titleSmall)),
                      Text(
                          '${Fmt.hours(i.weeklyCompletedMinutes)} / ${Fmt.hours(i.weeklyPlannedMinutes)} h',
                          style: t.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: i.weeklyPlannedMinutes == 0
                            ? 0
                            : i.weeklyCompletedMinutes / i.weeklyPlannedMinutes,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Completed vs planned sessions',
                        style: t.textTheme.bodySmall),
                  ]),
            ),

            // ---- upcoming events
            SectionHeader('Upcoming events',
                actionLabel: 'Calendar',
                onAction: () =>
                    Navigator.of(context).pushNamed(AppRoutes.calendar)),
            if (i.upcomingEvents.isEmpty)
              const _EmptyLine(
                  Icons.event_busy_outlined, 'No upcoming exams or events')
            else
              for (final e in i.upcomingEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EventCard(
                      event: e,
                      showDate: true,
                      onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.eventForm,
                          arguments: EventFormArgs(event: e))),
                ),

            // ---- recent activity
            const SectionHeader('Recent activity'),
            if (i.recent.isEmpty)
              const _EmptyLine(
                  Icons.history, 'Your recent changes will appear here')
            else
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final a in i.recent)
                    ListTile(
                      dense: true,
                      leading: Icon(_iconFor(a.kind), color: s.primary),
                      title: Text(a.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${a.kind} · ${Fmt.dateTime(a.at)}'),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'Course':
        return Icons.menu_book_outlined;
      case 'Assignment':
        return Icons.assignment_outlined;
      case 'Study session':
        return Icons.timer_outlined;
      case 'Note':
        return Icons.sticky_note_2_outlined;
      default:
        return Icons.event_outlined;
    }
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quick(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
            avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap),
      );
}

class _EmptyLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );
}
