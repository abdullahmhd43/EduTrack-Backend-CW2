import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../models/note.dart';
import '../common/app_card.dart';
import 'sync_badge.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String? courseName;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, this.courseName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          SyncBadge(note.syncStatus),
        ]),
        const SizedBox(height: 4),
        Text(note.content, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(children: [
          if (courseName != null) ...[
            Icon(Icons.menu_book_outlined, size: 14, color: t.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(child: Text(courseName!, overflow: TextOverflow.ellipsis, style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary))),
            const SizedBox(width: 10),
          ],
          Text('Created ${Fmt.shortDate(note.createdAt)}', style: t.textTheme.labelSmall),
        ]),
      ]),
    );
  }
}
