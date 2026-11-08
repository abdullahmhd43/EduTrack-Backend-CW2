import '../core/utils/date_utils.dart';
import 'sync_model.dart';

class StudySession extends SyncModel {
  final String courseId;
  final String topic, description;
  final String date; // yyyy-MM-dd
  final String startTime, endTime; // HH:mm
  final bool completed;

  const StudySession({
    required super.localId,
    super.serverId,
    super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.lastSyncedAt,
    required this.courseId,
    required this.topic,
    this.description = '',
    required this.date,
    required this.startTime,
    required this.endTime,
    this.completed = false,
  });

  factory StudySession.fromRow(Map<String, Object?> row) {
    final r = RowReader(row);
    return StudySession(
      localId: r.localId,
      serverId: r.serverId,
      syncStatus: r.syncStatus,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      lastSyncedAt: r.lastSyncedAt,
      courseId: r.s('courseClientId'),
      topic: r.s('topic'),
      description: r.s('description'),
      date: r.s('date'),
      startTime: r.s('startTime'),
      endTime: r.s('endTime'),
      completed: r.b('completed'),
    );
  }

  static Map<String, Object?> fields({
    required String courseId,
    required String topic,
    String description = '',
    required String date,
    required String startTime,
    required String endTime,
    bool completed = false,
  }) =>
      {
        'courseClientId': courseId,
        'topic': topic.trim(),
        'description': description.trim(),
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'completed': completed ? 1 : 0,
      };

  @override
  Map<String, Object?> toFields() => fields(
      courseId: courseId, topic: topic, description: description, date: date, startTime: startTime, endTime: endTime, completed: completed);

  DateTime get day => Fmt.parseYmd(date);
  int get minutes => Fmt.minutesBetween(startTime, endTime);
}
