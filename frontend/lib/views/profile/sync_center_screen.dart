import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../services/sync/sync_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/section_header.dart';

/// Shows connection/sync status, pending changes, failures, and lets the user resolve conflicts.
class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  List<ConflictInfo> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final c = await context.read<SyncService>().loadConflicts();
    if (mounted) setState(() => _conflicts = c);
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final t = Theme.of(context);
    String stateText;
    switch (sync.state) {
      case SyncState.online:
        stateText = 'Online';
      case SyncState.offline:
        stateText = 'Offline - changes are saved on this device';
      case SyncState.syncing:
        stateText = 'Synchronising…';
      case SyncState.failed:
        stateText = 'Sync failed';
      case SyncState.synced:
        stateText = 'Synced successfully';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Center')),
      body: RefreshIndicator(
        onRefresh: () async {
          await sync.syncNow(retryFailed: true);
          await _reload();
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stateText, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _Stat('Pending changes', '${sync.pendingCount}'),
              _Stat('Failed (will retry)', '${sync.failedCount}'),
              _Stat('Conflicts', '${sync.conflictCount}'),
              _Stat('Last synced', sync.lastSyncedAt == null ? 'Never' : Fmt.dateTime(sync.lastSyncedAt!)),
              if (sync.lastError != null) ...[
                const SizedBox(height: 8),
                Text(sync.lastError!, style: TextStyle(color: t.colorScheme.error)),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: sync.state == SyncState.syncing
                    ? null
                    : () async {
                        await sync.syncNow(retryFailed: true);
                        await _reload();
                        if (!context.mounted) return;
                        if (sync.state == SyncState.offline) {
                          Notify.info(context, 'Still offline. Changes will sync automatically when the server is reachable.');
                        }
                      },
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
              ),
            ]),
          ),
          const SectionHeader('Conflicts'),
          if (_conflicts.isEmpty)
            const AppCard(child: Text('No conflicts. Your changes never overwrite newer server data silently: if the same record changed in both places you choose which version to keep.'))
          else
            for (final c in _conflicts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.sync_problem, color: t.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${c.spec.table}: ${c.label}', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 8),
                    if (c.deletedOnServer)
                      const Text('This record was deleted on the server, but you edited it here.')
                    else ...[
                      const Text('Changed on the server after your last sync. Differences:'),
                      const SizedBox(height: 6),
                      for (final d in c.diffs)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• ${d.field}\n    mine: ${_short(d.mine)}\n    server: ${_short(d.server)}', style: t.textTheme.bodySmall),
                        ),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await sync.useServer(c);
                            await _reload();
                          },
                          child: Text(c.deletedOnServer ? 'Discard mine' : 'Use server'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                          onPressed: () async {
                            await sync.keepMine(c);
                            await _reload();
                          },
                          child: Text(c.deletedOnServer ? 'Re-create mine' : 'Keep mine'),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }

  String _short(String v) => v.length > 60 ? '${v.substring(0, 60)}…' : v;
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}
