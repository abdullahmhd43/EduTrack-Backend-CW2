import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/study_session_view_model.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/session_card.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  void _add(BuildContext context, StudySessionViewModel vm) {
    if (context.read<CourseViewModel>().items.isEmpty) {
      Notify.info(
        context,
        'Add a course first to plan study sessions for it.',
      );
      Navigator.of(context).pushNamed(AppRoutes.courseForm);
      return;
    }

    Navigator.of(context).pushNamed(
      AppRoutes.sessionForm,
      arguments: SessionFormArgs(day: vm.selectedDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StudySessionViewModel>();
    final courses = context.watch<CourseViewModel>();
    final list = vm.visible;
    final monday = Fmt.startOfWeek(vm.selectedDay);
    final totalMinutes = list.fold<int>(0, (a, s) => a + s.minutes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study planner'),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today),
            onPressed: () => vm.selectDay(DateTime.now()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Daily'),
                  icon: Icon(Icons.view_day_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Weekly'),
                  icon: Icon(Icons.view_week_outlined),
                ),
              ],
              selected: {vm.weekly},
              onSelectionChanged: (s) => vm.setWeekly(s.first),
            ),
          ),
          SizedBox(
            height: 78,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => vm.selectDay(
                    vm.selectedDay.subtract(const Duration(days: 7)),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _DayChip(
                            day: monday.add(Duration(days: i)),
                            selected: Fmt.sameDay(
                              monday.add(Duration(days: i)),
                              vm.selectedDay,
                            ),
                            count:
                                vm.forDay(monday.add(Duration(days: i))).length,
                            onTap: () => vm.selectDay(
                              monday.add(Duration(days: i)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => vm.selectDay(
                    vm.selectedDay.add(const Duration(days: 7)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vm.weekly
                        ? 'Week of ${Fmt.shortDate(monday)}'
                        : Fmt.pretty(vm.selectedDay),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${list.length} session${list.length == 1 ? '' : 's'} · ${Fmt.hours(totalMinutes)} h',
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.loading && vm.items.isEmpty
                ? const LoadingView()
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.event_available_outlined,
                        title: vm.weekly
                            ? 'Nothing planned this week'
                            : 'Nothing planned for this day',
                        message:
                            'Plan a focused study session for one of your courses.',
                        actionLabel: 'Plan session',
                        onAction: () => _add(context, vm),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final s = list[idx];

                          return SessionCard(
                            session: s,
                            courseName: courses.nameOf(s.courseId),
                            showDate: vm.weekly,
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.sessionForm,
                              arguments: SessionFormArgs(session: s),
                            ),
                            onToggle: () async {
                              final err = await vm.toggleCompleted(s);

                              if (err != null && context.mounted) {
                                Notify.error(context, err);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'planner_fab',
        onPressed: () => _add(context, vm),
        icon: const Icon(Icons.add),
        label: const Text('Session'),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? s.primary : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              names[day.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                color: selected ? s.onPrimary : s.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: selected ? s.onPrimary : s.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: count == 0
                    ? Colors.transparent
                    : (selected ? s.onPrimary : s.tertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
