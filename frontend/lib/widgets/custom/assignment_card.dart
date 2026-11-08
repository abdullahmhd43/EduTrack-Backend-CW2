import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/assignment.dart';
import '../common/app_card.dart';
import 'status_chip.dart';
import 'sync_badge.dart';

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final String courseName;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  const AssignmentCard({super.key, required this.assignment, required this.courseName, required this.onTap, required this.onToggleDone});

  Color get _priorityColor {
    switch (assignment.priority) {
      case Priority.high:
        return AppColors.danger;
      case Priority.medium:
        return AppColors.warning;
      case Priority.low:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final status = assignment.status;
    final done = status == AssignmentStatus.completed;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: _priorityColor),
          IconButton(
            tooltip: done ? 'Mark as not completed' : 'Mark as completed',
            onPressed: onToggleDone,
            icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AppColors.success : t.colorScheme.outline),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(assignment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700, decoration: done ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 2),
                Text(courseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  StatusChip.assignment(status),
                  StatusChip.priority(assignment.priority),
                  Text(done ? Fmt.shortDate(assignment.dueDate) : Fmt.relativeDue(assignment.dueDate), style: t.textTheme.bodySmall),
                ]),
              ]),
            ),
          ),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: SyncBadge(assignment.syncStatus))),
        ]),
      ),
    );
  }
}
