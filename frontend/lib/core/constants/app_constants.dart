
import 'package:flutter/foundation.dart' show kReleaseMode;

/// Central place for configuration & enum <-> label mappings.
class AppConfig {
  AppConfig._();

  /// New deployed backend (EthioDeploy).
  /// Release builds use this URL by default.
  static const String productionApiBaseUrl =
      'https://edutrack-backend-cw2.ethiodeploy.app/api';

  /// Android EMULATOR alias for the host computer's localhost (debug builds default to this).
  static const String emulatorApiBaseUrl =
      'http://10.0.2.2:5000/api';

  /// Override at build time using:
  /// flutter run --dart-define=API_BASE_URL=https://your-backend-url/api
  ///
  /// Default:
  /// Production URL in release builds.
  /// Emulator URL in debug builds.
  ///
  /// A physical phone with a local backend must use the computer's LAN IP,
  /// never localhost.
  ///
  /// The address can also be changed inside the app
  /// (login screen or Profile > Server address).
  static const String defaultApiBaseUrl =
      String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode
        ? productionApiBaseUrl
        : emulatorApiBaseUrl,
  );

  static const Duration requestTimeout = Duration(seconds: 12);
  static const int maxSyncAttempts = 5;
  static const String appName = 'EduTrack';
}

enum Priority { low, medium, high }

enum AssignmentStatus {
  notStarted,
  inProgress,
  completed,
  overdue
}

enum EventType {
  exam,
  classSchedule,
  event
}

extension PriorityX on Priority {
  String get api => name;

  String get label =>
      name[0].toUpperCase() + name.substring(1);

  static Priority parse(String? v) =>
      Priority.values.firstWhere(
        (e) => e.name == v,
        orElse: () => Priority.medium,
      );
}

extension AssignmentStatusX on AssignmentStatus {
  /// Value stored locally and on the server.
  /// "overdue" is never stored - it is derived.
  String get api {
    switch (this) {
      case AssignmentStatus.notStarted:
        return 'not_started';
      case AssignmentStatus.inProgress:
        return 'in_progress';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.overdue:
        return 'not_started';
    }
  }

  String get label {
    switch (this) {
      case AssignmentStatus.notStarted:
        return 'Not Started';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.overdue:
        return 'Overdue';
    }
  }

  static AssignmentStatus parse(String? v) {
    switch (v) {
      case 'in_progress':
        return AssignmentStatus.inProgress;
      case 'completed':
        return AssignmentStatus.completed;
      default:
        return AssignmentStatus.notStarted;
    }
  }
}

extension EventTypeX on EventType {
  String get api =>
      this == EventType.classSchedule ? 'class' : name;

  String get label =>
      this == EventType.classSchedule
          ? 'Class'
          : name[0].toUpperCase() + name.substring(1);

  static EventType parse(String? v) {
    if (v == 'class') return EventType.classSchedule;
    if (v == 'exam') return EventType.exam;
    return EventType.event;
  }
}
