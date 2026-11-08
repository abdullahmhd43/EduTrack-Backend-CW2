import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../services/sync/sync_service.dart';
import '../../widgets/common/app_card.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final items = <_Item>[
      _Item(Icons.sticky_note_2_outlined, 'Notes', 'Academic notes', AppRoutes.notes),
      _Item(Icons.calendar_month_outlined, 'Calendar', 'Exams, classes & events', AppRoutes.calendar),
      _Item(Icons.insights_outlined, 'Progress', 'Charts & statistics', AppRoutes.progress),
      _Item(Icons.sync_alt, 'Sync Center', sync.conflictCount > 0 ? '${sync.conflictCount} conflict(s) to review' : 'Status & pending changes', AppRoutes.syncCenter),
      _Item(Icons.person_outline, 'Profile & Settings', 'Account, server, logout', AppRoutes.profile),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          for (final i in items)
            AppCard(
              onTap: () => Navigator.of(context).pushNamed(i.route),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(i.icon, size: 32, color: Theme.of(context).colorScheme.primary),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(i.subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String title, subtitle, route;
  _Item(this.icon, this.title, this.subtitle, this.route);
}
