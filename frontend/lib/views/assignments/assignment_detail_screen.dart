import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/assignment_view_model.dart';
import '../../viewmodels/course_view_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/status_chip.dart';
import '../../widgets/custom/sync_badge.dart';

class AssignmentDetailScreen extends StatelessWidget {
  final String assignmentId;
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();
    final a = vm.byId(assignmentId);
    if (a == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Assignment not found', message: 'It may have been deleted.'));
    }
    final course = context.watch<CourseViewModel>().byId(a.courseId);
    final t = Theme.of(context);
    final status = a.status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment'),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).pushNamed(AppRoutes.assignmentForm, arguments: AssignmentFormArgs(assignment: a))),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Delete assignment?', message: '"${a.title}" will be removed.', confirmLabel: 'Delete', destructive: true);
              if (!ok || !context.mounted) return;
              final err = await vm.delete(a.localId);
              if (!context.mounted) return;
              if (err != null) {
                Notify.error(context, err);
              } else {
                Notify.success(context, 'Assignment deleted');
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
              Expanded(child: Text(a.title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              SyncBadge(a.syncStatus),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [StatusChip.assignment(status), StatusChip.priority(a.priority)]),
            const Divider(height: 28),
            _Line(Icons.menu_book_outlined, 'Course', course == null ? 'Unknown' : '${course.code} · ${course.name}'),
            _Line(Icons.event_outlined, 'Due', Fmt.dateTime(a.dueDate)),
            _Line(Icons.hourglass_bottom, 'Time left', a.isCompleted ? 'Completed' : Fmt.relativeDue(a.dueDate)),
            if (a.description.isNotEmpty) ...[const Divider(height: 28), Text(a.description)],
          ]),
        ),
        const SizedBox(height: 16),
        Text('Update status', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<AssignmentStatus>(
          segments: const [
            ButtonSegment(value: AssignmentStatus.notStarted, label: Text('Not started')),
            ButtonSegment(value: AssignmentStatus.inProgress, label: Text('In progress')),
            ButtonSegment(value: AssignmentStatus.completed, label: Text('Done')),
          ],
          selected: {a.storedStatus},
          onSelectionChanged: (s) async {
            final err = await vm.changeStatus(a, s.first);
            if (context.mounted) {
              if (err != null) {
                Notify.error(context, err);
              } else {
                Notify.success(context, 'Status updated');
              }
            }
          },
        ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Line(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(width: 72, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
