import '../services/database/entity_spec.dart';

DateTime? _dt(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// Fields shared by every synchronised model (see the "common columns" in AppDatabase).
abstract class SyncModel {
  final String localId;
  final String? serverId;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  const SyncModel({
    required this.localId,
    this.serverId,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  bool get isPending => syncStatus == SyncStatus.pending;
  bool get hasConflict => syncStatus == SyncStatus.conflict;

  /// Business columns only (what a form edits). Sync columns are managed by the repository.
  Map<String, Object?> toFields();
}

/// Helper for model factories.
class RowReader {
  final Map<String, Object?> r;
  const RowReader(this.r);
  String s(String k) => (r[k] as String?) ?? '';
  String? sn(String k) => r[k] as String?;
  DateTime d(String k) => DateTime.parse(r[k] as String);
  bool b(String k) => (r[k] as int? ?? 0) == 1;
  String get localId => r['localId'] as String;
  String? get serverId => r['serverId'] as String?;
  String get syncStatus => (r['syncStatus'] as String?) ?? SyncStatus.synced;
  DateTime get createdAt => d('createdAt');
  DateTime get updatedAt => d('updatedAt');
  DateTime? get lastSyncedAt => _dt(r['lastSyncedAt']);
}
