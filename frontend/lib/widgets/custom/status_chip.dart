import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Small coloured pill used for assignment status, priority and event type.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusChip({super.key, required this.label, required this.color, this.icon});

  factory StatusChip.assignment(AssignmentStatus s) {
    switch (s) {
      case AssignmentStatus.completed:
        return const StatusChip(label: 'Completed', color: AppColors.success, icon: Icons.check_circle_outline);
      case AssignmentStatus.inProgress:
        return const StatusChip(label: 'In Progress', color: AppColors.info, icon: Icons.timelapse);
      case AssignmentStatus.overdue:
        return const StatusChip(label: 'Overdue', color: AppColors.danger, icon: Icons.warning_amber_rounded);
      case AssignmentStatus.notStarted:
        return const StatusChip(label: 'Not Started', color: Colors.blueGrey, icon: Icons.radio_button_unchecked);
    }
  }

  factory StatusChip.priority(Priority p) {
    switch (p) {
      case Priority.high:
        return const StatusChip(label: 'High', color: AppColors.danger, icon: Icons.flag);
      case Priority.medium:
        return const StatusChip(label: 'Medium', color: AppColors.warning, icon: Icons.flag);
      case Priority.low:
        return const StatusChip(label: 'Low', color: AppColors.success, icon: Icons.flag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
