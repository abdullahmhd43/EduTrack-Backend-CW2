import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/event_view_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/custom/event_card.dart';
import '../../widgets/custom/month_calendar.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventViewModel>();
    final dayEvents = vm.forDay(vm.selectedDay);
    final upcoming = vm.upcoming(limit: 10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic calendar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          AppCard(
            padding: const EdgeInsets.all(8),
            child: MonthCalendar(
              focusedMonth: vm.focusedMonth,
              selectedDay: vm.selectedDay,
              eventCounts: vm.countsByDay,
              onDaySelected: vm.selectDay,
              onMonthChanged: vm.changeMonth,
            ),
          ),
          SectionHeader(
            Fmt.pretty(vm.selectedDay),
            actionLabel: 'Add',
            onAction: () => Navigator.of(context).pushNamed(
              AppRoutes.eventForm,
              arguments: EventFormArgs(day: vm.selectedDay),
            ),
          ),
          if (dayEvents.isEmpty)
            const AppCard(
              child: Text('No exams, classes or events on this day.'),
            )
          else
            for (final e in dayEvents)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EventCard(
                  event: e,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.eventForm,
                    arguments: EventFormArgs(event: e),
                  ),
                ),
              ),
          const SectionHeader('Upcoming'),
          if (upcoming.isEmpty)
            const AppCard(
              child: Text(
                'Nothing upcoming. Add your exams and class schedule.',
              ),
            )
          else
            for (final e in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EventCard(
                  event: e,
                  showDate: true,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.eventForm,
                    arguments: EventFormArgs(event: e),
                  ),
                ),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar_fab',
        onPressed: () => Navigator.of(context).pushNamed(
          AppRoutes.eventForm,
          arguments: EventFormArgs(day: vm.selectedDay),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Event'),
      ),
    );
  }
}
