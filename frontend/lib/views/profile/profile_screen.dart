import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../services/sync/sync_service.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/server_url_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final sync = context.read<SyncService>();
    final auth = context.read<AuthViewModel>();
    final pending = sync.pendingCount;
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: pending > 0
          ? 'You have $pending change(s) not yet synced. They stay safely on this device and sync after you log in again.'
          : 'You will need to log in again to sync with the server.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok) return;
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final sync = context.watch<SyncService>();
    final user = auth.user;
    final t = Theme.of(context);
    final s = t.colorScheme;
    if (user == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: s.primaryContainer,
              child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: s.onPrimaryContainer)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(user.email, style: t.textTheme.bodyMedium),
              ]),
            ),
            IconButton(tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined), onPressed: () => Navigator.of(context).pushNamed(AppRoutes.editProfile)),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Student ID'), subtitle: Text(user.studentId.isEmpty ? 'Not set' : user.studentId)),
            ListTile(leading: const Icon(Icons.school_outlined), title: const Text('Programme'), subtitle: Text(user.program.isEmpty ? 'Not set' : user.program)),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.sync_alt),
              title: const Text('Sync Center'),
              subtitle: Text(sync.lastSyncedAt == null ? 'Not synced yet' : 'Last synced ${Fmt.dateTime(sync.lastSyncedAt!)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.syncCenter),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Server address'),
              subtitle: Text(auth.apiConfig.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showServerUrlDialog(context),
            ),
            const ListTile(leading: Icon(Icons.info_outline), title: Text('About'), subtitle: Text('EduTrack 1.0.0 · CI6330 Coursework 2')),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: s.error),
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ]),
    );
  }
}
