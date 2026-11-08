import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/assignment_view_model.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/note_view_model.dart';
import '../../viewmodels/study_session_view_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/assignment_card.dart';
import '../../widgets/custom/progress_ring.dart';
import '../../widgets/custom/sync_badge.dart';

class CourseDetailScreen extends StatelessWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CourseViewModel>();
    final course = vm.byId(courseId);
    if (course == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Course not found', message: 'It may have been deleted.'));
    }
    final aVm = context.watch<AssignmentViewModel>();
    final assignments = aVm.forCourse(courseId);
    final done = assignments.where((a) => a.isCompleted).length;
    final notes = context.watch<NoteViewModel>().items.where((n) => n.courseId == courseId).length;
    final sessions = context.watch<StudySessionViewModel>().items.where((s) => s.courseId == courseId).length;
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(course.code),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).pushNamed(AppRoutes.courseForm, arguments: course)),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: 'Delete course?',
                  message: 'This also deletes its ${assignments.length} assignment(s), $sessions study session(s) and $notes note(s).',
                  confirmLabel: 'Delete',
                  destructive: true);
              if (!ok || !context.mounted) return;
              final err = await vm.delete(courseId);
              if (!context.mounted) return;
              if (err != null) {
                Notify.error(context, err);
              } else {
                Notify.success(context, 'Course deleted');
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(course.name, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              SyncBadge(course.syncStatus),
            ]),
            const SizedBox(height: 10),
            _Row(Icons.tag, course.code),
            if (course.lecturer.isNotEmpty) _Row(Icons.person_outline, course.lecturer),
            _Row(Icons.date_range_outlined, '${Fmt.pretty(course.startDate)}  →  ${Fmt.pretty(course.endDate)}'),
            if (course.description.isNotEmpty) ...[const Divider(height: 24), Text(course.description)],
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(children: [
            ProgressRing(
                value: assignments.isEmpty ? 0 : done / assignments.length,
                size: 72,
                strokeWidth: 8,
                center: Text(assignments.isEmpty ? '–' : '${(done / assignments.length * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$done of ${assignments.length} assignments completed', style: t.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text('$sessions study session(s) · $notes note(s)', style: t.textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
        SectionHeader('Assignments', actionLabel: 'Add', onAction: () => Navigator.of(context).pushNamed(AppRoutes.assignmentForm, arguments: AssignmentFormArgs(courseId: courseId))),
        if (assignments.isEmpty)
          const AppCard(child: Text('No assignments for this course yet.'))
        else
          for (final a in assignments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AssignmentCard(
                assignment: a,
                courseName: course.name,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.assignmentDetail, arguments: a.localId),
                onToggleDone: () => aVm.changeStatus(a, a.isCompleted ? AssignmentStatus.notStarted : AssignmentStatus.completed),
              ),
            ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text(text))]),
      );
}
