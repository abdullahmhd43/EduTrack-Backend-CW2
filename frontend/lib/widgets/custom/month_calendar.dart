import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';

/// Custom month-grid calendar (built from scratch). Shows dots under days that have events.
class MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, int> eventCounts; // yyyy-MM-dd -> count
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onMonthChanged; // -1 / +1

  const MonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.eventCounts,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lead = first.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final rows = ((lead + daysInMonth) / 7).ceil();
    final today = Fmt.dayOnly(DateTime.now());

    Widget cell(int index) {
      final dayNum = index - lead + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox(height: 48);
      final date = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
      final selected = Fmt.sameDay(date, selectedDay);
      final isToday = Fmt.sameDay(date, today);
      final count = eventCounts[Fmt.ymd(date)] ?? 0;
      return InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onDaySelected(date),
        child: SizedBox(
          height: 48,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : null,
                border: (isToday && !selected) ? Border.all(color: scheme.primary, width: 1.5) : null,
              ),
              child: Text('$dayNum',
                  style: TextStyle(
                    fontWeight: (selected || isToday) ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  )),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < count.clamp(0, 3); i++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
                  ),
              ]),
            ),
          ]),
        ),
      );
    }

    return Column(children: [
      Row(children: [
        IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left), onPressed: () => onMonthChanged(-1)),
        Expanded(
          child: Text(Fmt.month(focusedMonth),
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(tooltip: 'Next month', icon: const Icon(Icons.chevron_right), onPressed: () => onMonthChanged(1)),
      ]),
      Row(children: [
        for (final d in _weekdays)
          Expanded(
            child: Center(
              child: Text(d, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      for (var r = 0; r < rows; r++)
        Row(children: [for (var c = 0; c < 7; c++) Expanded(child: cell(r * 7 + c))]),
    ]);
  }
}
