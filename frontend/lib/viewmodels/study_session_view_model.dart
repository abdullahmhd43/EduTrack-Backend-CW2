import '../core/utils/date_utils.dart';
import '../models/study_session.dart';
import 'entity_view_model.dart';

class StudySessionViewModel extends EntityViewModel<StudySession> {
  StudySessionViewModel(super.repo);

  DateTime selectedDay = Fmt.dayOnly(DateTime.now());
  bool weekly = false;

  void selectDay(DateTime d) {
    selectedDay = Fmt.dayOnly(d);
    refreshView();
  }

  void setWeekly(bool v) {
    weekly = v;
    refreshView();
  }

  int _cmp(StudySession a, StudySession b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.startTime.compareTo(b.startTime);
  }

  List<StudySession> forDay(DateTime d) {
    final key = Fmt.ymd(d);
    return items.where((s) => s.date == key).toList()..sort(_cmp);
  }

  List<StudySession> forWeek(DateTime anyDayInWeek) {
    final start = Fmt.startOfWeek(anyDayInWeek);
    final keys = {for (var i = 0; i < 7; i++) Fmt.ymd(start.add(Duration(days: i)))};
    return items.where((s) => keys.contains(s.date)).toList()..sort(_cmp);
  }

  List<StudySession> get visible => weekly ? forWeek(selectedDay) : forDay(selectedDay);

  Future<String?> toggleCompleted(StudySession s) => update(
        s.localId,
        StudySession.fields(
            courseId: s.courseId, topic: s.topic, description: s.description, date: s.date, startTime: s.startTime, endTime: s.endTime, completed: !s.completed),
      );
}
