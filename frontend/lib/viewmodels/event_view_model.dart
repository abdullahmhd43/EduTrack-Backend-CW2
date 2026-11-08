import '../core/utils/date_utils.dart';
import '../models/academic_event.dart';
import 'entity_view_model.dart';

class EventViewModel extends EntityViewModel<AcademicEvent> {
  EventViewModel(super.repo);

  DateTime focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDay = Fmt.dayOnly(DateTime.now());

  void selectDay(DateTime d) {
    selectedDay = Fmt.dayOnly(d);
    if (d.month != focusedMonth.month || d.year != focusedMonth.year) focusedMonth = DateTime(d.year, d.month);
    refreshView();
  }

  void changeMonth(int delta) {
    focusedMonth = DateTime(focusedMonth.year, focusedMonth.month + delta);
    refreshView();
  }

  int _cmp(AcademicEvent a, AcademicEvent b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.startTime.compareTo(b.startTime);
  }

  List<AcademicEvent> forDay(DateTime d) {
    final key = Fmt.ymd(d);
    return items.where((e) => e.date == key).toList()..sort(_cmp);
  }

  /// yyyy-MM-dd -> number of events (drives the dots in the calendar grid).
  Map<String, int> get countsByDay {
    final m = <String, int>{};
    for (final e in items) {
      m[e.date] = (m[e.date] ?? 0) + 1;
    }
    return m;
  }

  List<AcademicEvent> upcoming({DateTime? now, int? limit}) {
    final n = now ?? DateTime.now();
    final list = items.where((e) => !e.startsAt.isBefore(Fmt.dayOnly(n))).toList()..sort(_cmp);
    return limit == null ? list : list.take(limit).toList();
  }
}
