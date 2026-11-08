import 'sync_model.dart';

class Note extends SyncModel {
  final String? courseId;
  final String title, content;

  const Note({
    required super.localId,
    super.serverId,
    super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.lastSyncedAt,
    this.courseId,
    required this.title,
    required this.content,
  });

  factory Note.fromRow(Map<String, Object?> row) {
    final r = RowReader(row);
    final c = r.sn('courseClientId');
    return Note(
      localId: r.localId,
      serverId: r.serverId,
      syncStatus: r.syncStatus,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      lastSyncedAt: r.lastSyncedAt,
      courseId: (c == null || c.isEmpty) ? null : c,
      title: r.s('title'),
      content: r.s('content'),
    );
  }

  static Map<String, Object?> fields({String? courseId, required String title, required String content}) =>
      {'courseClientId': courseId, 'title': title.trim(), 'content': content.trim()};

  @override
  Map<String, Object?> toFields() => fields(courseId: courseId, title: title, content: content);
}
