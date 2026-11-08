import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../models/study_session.dart';
import '../common/app_card.dart';
import 'sync_badge.dart';

class SessionCard extends StatelessWidget {
  final StudySession session;
  final String courseName;
  final bool showDate;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const SessionCard({super.key, required this.session, required this.courseName, this.showDate = false, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      child: Row(children: [
        IconButton(
          tooltip: session.completed ? 'Mark as planned' : 'Mark as done',
          onPressed: onToggle,
          icon: Icon(session.completed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: session.completed ? AppColors.success : t.colorScheme.outline),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700, decoration: session.completed ? TextDecoration.lineThrough : null)),
            Text(courseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (showDate) Text(Fmt.shortDate(session.day), style: t.textTheme.labelSmall),
          Text('${session.startTime} – ${session.endTime}', style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          Text('${Fmt.hours(session.minutes)} h', style: t.textTheme.labelSmall),
        ]),
        const SizedBox(width: 6),
        SyncBadge(session.syncStatus),
      ]),
    );
  }
}
