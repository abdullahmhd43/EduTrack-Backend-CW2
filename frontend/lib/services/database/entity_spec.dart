/// Declarative description of each synchronised entity (one SQLite table <-> one REST resource).
/// The generic LocalStore, SyncService and repositories are driven by these specs, so adding an
/// entity means adding one spec + one model instead of copying sync code.
class EntitySpec {
  final String table;
  final String apiPath;
  final String labelField; // human readable column used in conflict screens
  final List<String> textFields;
  final List<String> intFields; // booleans stored as 0/1
  final String? parentField; // foreign key -> courses.localId
  final bool parentRequired;

  const EntitySpec({
    required this.table,
    required this.apiPath,
    required this.labelField,
    required this.textFields,
    this.intFields = const [],
    this.parentField,
    this.parentRequired = false,
  });

  List<String> get fields => [...textFields, ...intFields];
  bool isInt(String f) => intFields.contains(f);

  /// Row -> JSON body for the REST API (ints become bools).
  Map<String, dynamic> toApiBody(Map<String, Object?> row) => {
        for (final f in textFields) f: row[f],
        for (final f in intFields) f: (row[f] as int? ?? 0) == 1,
      };

  /// Server document -> business columns of a local row.
  Map<String, Object?> fieldsFromApi(Map<String, dynamic> doc) => {
        for (final f in textFields) f: doc[f],
        for (final f in intFields) f: (doc[f] == true) ? 1 : 0,
      };
}

class Specs {
  Specs._();

  static const course = EntitySpec(
    table: 'courses',
    apiPath: '/courses',
    labelField: 'name',
    textFields: ['name', 'code', 'lecturer', 'description', 'startDate', 'endDate'],
  );

  static const assignment = EntitySpec(
    table: 'assignments',
    apiPath: '/assignments',
    labelField: 'title',
    textFields: ['courseClientId', 'title', 'description', 'dueDate', 'priority', 'status'],
    parentField: 'courseClientId',
    parentRequired: true,
  );

  static const studySession = EntitySpec(
    table: 'study_sessions',
    apiPath: '/study-sessions',
    labelField: 'topic',
    textFields: ['courseClientId', 'topic', 'date', 'startTime', 'endTime', 'description'],
    intFields: ['completed'],
    parentField: 'courseClientId',
    parentRequired: true,
  );

  static const note = EntitySpec(
    table: 'notes',
    apiPath: '/notes',
    labelField: 'title',
    textFields: ['courseClientId', 'title', 'content'],
    parentField: 'courseClientId',
    parentRequired: false,
  );

  static const event = EntitySpec(
    table: 'events',
    apiPath: '/events',
    labelField: 'title',
    textFields: ['title', 'type', 'date', 'startTime', 'endTime', 'location', 'description'],
  );

  /// Dependency order: parents first (used for push order; reversed for deletes).
  static const List<EntitySpec> all = [course, assignment, studySession, note, event];

  static EntitySpec byTable(String t) => all.firstWhere((s) => s.table == t);
}

/// Values of the syncStatus column.
class SyncStatus {
  SyncStatus._();
  static const synced = 'synced';
  static const pending = 'pending';
  static const conflict = 'conflict';
}

/// Values of sync_queue.operation.
class SyncOp {
  SyncOp._();
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
}
