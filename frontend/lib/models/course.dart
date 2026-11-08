import 'sync_model.dart';

class Course extends SyncModel {
  final String name, code, lecturer, description;
  final DateTime startDate, endDate;

  const Course({
    required super.localId,
    super.serverId,
    super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.lastSyncedAt,
    required this.name,
    required this.code,
    this.lecturer = '',
    this.description = '',
    required this.startDate,
    required this.endDate,
  });

  factory Course.fromRow(Map<String, Object?> row) {
    final r = RowReader(row);
    return Course(
      localId: r.localId,
      serverId: r.serverId,
      syncStatus: r.syncStatus,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      lastSyncedAt: r.lastSyncedAt,
      name: r.s('name'),
      code: r.s('code'),
      lecturer: r.s('lecturer'),
      description: r.s('description'),
      startDate: r.d('startDate'),
      endDate: r.d('endDate'),
    );
  }

  /// Form data (no sync columns). Dates are stored as UTC ISO strings.
  static Map<String, Object?> fields({
    required String name,
    required String code,
    String lecturer = '',
    String description = '',
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'lecturer': lecturer.trim(),
        'description': description.trim(),
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
      };

  @override
  Map<String, Object?> toFields() =>
      fields(name: name, code: code, lecturer: lecturer, description: description, startDate: startDate, endDate: endDate);
}
