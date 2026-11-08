import '../core/constants/app_constants.dart';
import 'sync_model.dart';

class Assignment extends SyncModel {
  final String courseId; // = Course.localId
  final String title, description;
  final DateTime dueDate;
  final Priority priority;
  final AssignmentStatus storedStatus; // notStarted | inProgress | completed

  const Assignment({
    required super.localId,
    super.serverId,
    super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.lastSyncedAt,
    required this.courseId,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.priority = Priority.medium,
    this.storedStatus = AssignmentStatus.notStarted,
  });

  factory Assignment.fromRow(Map<String, Object?> row) {
    final r = RowReader(row);
    return Assignment(
      localId: r.localId,
      serverId: r.serverId,
      syncStatus: r.syncStatus,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      lastSyncedAt: r.lastSyncedAt,
      courseId: r.s('courseClientId'),
      title: r.s('title'),
      description: r.s('description'),
      dueDate: r.d('dueDate'),
      priority: PriorityX.parse(r.s('priority')),
      storedStatus: AssignmentStatusX.parse(r.s('status')),
    );
  }

  static Map<String, Object?> fields({
    required String courseId,
    required String title,
    String description = '',
    required DateTime dueDate,
    required Priority priority,
    required AssignmentStatus status,
  }) =>
      {
        'courseClientId': courseId,
        'title': title.trim(),
        'description': description.trim(),
        'dueDate': dueDate.toUtc().toIso8601String(),
        'priority': priority.api,
        'status': status.api,
      };

  @override
  Map<String, Object?> toFields() => fields(
      courseId: courseId, title: title, description: description, dueDate: dueDate, priority: priority, status: storedStatus);

  /// "Overdue" is derived: not completed and the due date has passed.
  AssignmentStatus statusAt(DateTime now) {
    if (storedStatus == AssignmentStatus.completed) return AssignmentStatus.completed;
    if (dueDate.isBefore(now)) return AssignmentStatus.overdue;
    return storedStatus;
  }

  AssignmentStatus get status => statusAt(DateTime.now());
  bool get isCompleted => storedStatus == AssignmentStatus.completed;
}
