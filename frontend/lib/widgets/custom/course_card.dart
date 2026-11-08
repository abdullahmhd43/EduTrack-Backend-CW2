import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../models/course.dart';
import '../common/app_card.dart';
import 'sync_badge.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final int assignmentCount;
  final VoidCallback onTap;

  const CourseCard({super.key, required this.course, required this.assignmentCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.primaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.menu_book_rounded, color: s.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(course.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${course.code}${course.lecturer.isEmpty ? '' : '  ·  ${course.lecturer}'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('${Fmt.shortDate(course.startDate)} – ${Fmt.shortDate(course.endDate)}  ·  $assignmentCount assignment${assignmentCount == 1 ? '' : 's'}',
                style: t.textTheme.bodySmall),
          ]),
        ),
        SyncBadge(course.syncStatus),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}
