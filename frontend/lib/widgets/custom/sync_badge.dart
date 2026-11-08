import 'package:flutter/material.dart';

import '../../services/database/entity_spec.dart';

/// Per-record sync indicator: pending upload / conflict. Nothing is shown for synced records.
class SyncBadge extends StatelessWidget {
  final String status;
  const SyncBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.pending) {
      return const Tooltip(message: 'Waiting to sync', child: Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFFEF6C00)));
    }
    if (status == SyncStatus.conflict) {
      return const Tooltip(message: 'Sync conflict', child: Icon(Icons.sync_problem, size: 18, color: Color(0xFFC62828)));
    }
    return const SizedBox.shrink();
  }
}
