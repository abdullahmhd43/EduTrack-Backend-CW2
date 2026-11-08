import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/academic_event.dart';
import '../common/app_card.dart';
import 'sync_badge.dart';

class EventCard extends StatelessWidget {
  final AcademicEvent event;
  final bool showDate;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, this.showDate = false, required this.onTap});

  (IconData, Color) get _style {
    switch (event.type) {
      case EventType.exam:
        return (Icons.assignment_late_outlined, AppColors.danger);
      case EventType.classSchedule:
        return (Icons.school_outlined, AppColors.info);
      case EventType.event:
        return (Icons.event_outlined, AppColors.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (icon, color) = _style;
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              '${event.type.label}${showDate ? '  ·  ${event.date}' : ''}  ·  ${event.startTime}${event.endTime.isEmpty ? '' : ' – ${event.endTime}'}',
              style: t.textTheme.bodySmall,
            ),
            if (event.location.isNotEmpty)
              Row(children: [
                Icon(Icons.place_outlined, size: 14, color: t.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Expanded(child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall)),
              ]),
          ]),
        ),
        SyncBadge(event.syncStatus),
      ]),
    );
  }
}
