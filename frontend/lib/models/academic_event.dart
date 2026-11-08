import '../core/constants/app_constants.dart';
import '../core/utils/date_utils.dart';
import 'sync_model.dart';

class AcademicEvent extends SyncModel {
  final String title, date, startTime, endTime, location, description;
  final EventType type;

  const AcademicEvent({
    required super.localId,
    super.serverId,
    super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.lastSyncedAt,
    required this.title,
    required this.type,
    required this.date,
    required this.startTime,
    this.endTime = '',
    this.location = '',
    this.description = '',
  });

  factory AcademicEvent.fromRow(Map<String, Object?> row) {
    final r = RowReader(row);
    return AcademicEvent(
      localId: r.localId,
      serverId: r.serverId,
      syncStatus: r.syncStatus,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      lastSyncedAt: r.lastSyncedAt,
      title: r.s('title'),
      type: EventTypeX.parse(r.s('type')),
      date: r.s('date'),
      startTime: r.s('startTime'),
      endTime: r.s('endTime'),
      location: r.s('location'),
      description: r.s('description'),
    );
  }

  static Map<String, Object?> fields({
    required String title,
    required EventType type,
    required String date,
    required String startTime,
    String endTime = '',
    String location = '',
    String description = '',
  }) =>
      {
        'title': title.trim(),
        'type': type.api,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'location': location.trim(),
        'description': description.trim(),
      };

  @override
  Map<String, Object?> toFields() =>
      fields(title: title, type: type, date: date, startTime: startTime, endTime: endTime, location: location, description: description);

  DateTime get day => Fmt.parseYmd(date);

  /// Start instant in local time.
  DateTime get startsAt {
    final p = startTime.split(':');
    return DateTime(day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
  }
}
