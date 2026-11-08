import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../routes/app_routes.dart';
import '../../services/sync/sync_service.dart';

/// Always-visible connection/sync indicator: Online, Offline, Synchronising, Sync failed, Synced successfully.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    late final String label;
    late final IconData icon;
    late final Color color;
    var spinning = false;

    switch (sync.state) {
      case SyncState.online:
        label = 'Online';
        icon = Icons.cloud_queue;
        color = AppColors.info;
      case SyncState.offline:
        label = 'Offline';
        icon = Icons.cloud_off;
        color = Colors.blueGrey;
      case SyncState.syncing:
        label = 'Synchronising…';
        icon = Icons.sync;
        color = AppColors.info;
        spinning = true;
      case SyncState.failed:
        label = 'Sync failed';
        icon = Icons.error_outline;
        color = AppColors.danger;
      case SyncState.synced:
        label = 'Synced successfully';
        icon = Icons.cloud_done;
        color = AppColors.success;
    }

    final extras = <String>[
      if (sync.pendingCount > 0) '${sync.pendingCount} pending',
      if (sync.conflictCount > 0) '${sync.conflictCount} conflict${sync.conflictCount == 1 ? '' : 's'}',
      if (sync.state == SyncState.synced && sync.lastSyncedAt != null) Fmt.time(sync.lastSyncedAt!.hour, sync.lastSyncedAt!.minute),
    ];

    return Material(
      color: color.withAlpha(28),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.syncCenter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            spinning
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            if (extras.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text('· ${extras.join(' · ')}',
                    overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12)),
              ),
            ] else
              const Spacer(),
            if (sync.state == SyncState.failed || (sync.state == SyncState.offline && sync.pendingCount > 0))
              Icon(Icons.chevron_right, size: 18, color: color),
          ]),
        ),
      ),
    );
  }
}
