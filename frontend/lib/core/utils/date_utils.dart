import 'package:intl/intl.dart';

/// Date/time helpers. Storage formats: dates "yyyy-MM-dd", times "HH:mm", instants ISO-8601 (UTC).
class Fmt {
  Fmt._();
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _pretty = DateFormat('EEE, d MMM yyyy');
  static final _short = DateFormat('d MMM');
  static final _month = DateFormat('MMMM yyyy');

  static String ymd(DateTime d) => _ymd.format(d);
  static DateTime parseYmd(String s) => _ymd.parseStrict(s);
  static String pretty(DateTime d) => _pretty.format(d.toLocal());
  static String shortDate(DateTime d) => _short.format(d.toLocal());
  static String month(DateTime d) => _month.format(d);
  static String dateTime(DateTime d) => '${_pretty.format(d.toLocal())}, ${DateFormat('HH:mm').format(d.toLocal())}';
  static String time(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Monday of the week containing [d].
  static DateTime startOfWeek(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));

  /// Minutes between two "HH:mm" strings (0 if invalid or negative).
  static int minutesBetween(String start, String end) {
    int? p(String t) {
      final parts = t.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      return (h == null || m == null) ? null : h * 60 + m;
    }

    final s = p(start), e = p(end);
    if (s == null || e == null || e <= s) return 0;
    return e - s;
  }

  static String hours(int minutes) => (minutes / 60).toStringAsFixed(1);

  static String relativeDue(DateTime due, {DateTime? now}) {
    final n = Fmt.dayOnly(now ?? DateTime.now());
    final d = Fmt.dayOnly(due.toLocal());
    final diff = d.difference(n).inDays;
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff == -1) return 'Due yesterday';
    if (diff < 0) return '${-diff} days overdue';
    return 'Due in $diff days';
  }
}
