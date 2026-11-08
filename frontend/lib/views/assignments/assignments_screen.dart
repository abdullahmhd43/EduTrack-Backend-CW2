import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/assignment_view_model.dart';
import '../../viewmodels/course_view_model.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/assignment_card.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add() {
    final courses = context.read<CourseViewModel>();

    if (courses.items.isEmpty) {
      Notify.info(
        context,
        'Add a course first, then you can add assignments to it.',
      );
      Navigator.of(context).pushNamed(AppRoutes.courseForm);
      return;
    }

    Navigator.of(context).pushNamed(AppRoutes.assignmentForm);
  }

  Future<void> _filterSheet() async {
    final vm = context.read<AssignmentViewModel>();
    final courses = context.read<CourseViewModel>().sorted;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget group(String title, List<Widget> chips) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: chips,
                    ),
                  ],
                ),
              );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter assignments',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          vm.clearFilters();
                          _search.clear();
                          setSheet(() {});
                        },
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                  group(
                    'Status',
                    [
                      for (final s in AssignmentStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: vm.status == s,
                          onSelected: (v) {
                            vm.setStatusFilter(v ? s : null);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                  group(
                    'Priority',
                    [
                      for (final p in Priority.values)
                        FilterChip(
                          label: Text(p.label),
                          selected: vm.priority == p,
                          onSelected: (v) {
                            vm.setPriorityFilter(v ? p : null);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                  if (courses.isNotEmpty)
                    group(
                      'Course',
                      [
                        for (final c in courses)
                          FilterChip(
                            label: Text(c.code),
                            selected: vm.courseId == c.localId,
                            onSelected: (v) {
                              vm.setCourseFilter(v ? c.localId : null);
                              setSheet(() {});
                            },
                          ),
                      ],
                    ),
                  group(
                    'Due date',
                    [
                      ActionChip(
                        avatar: const Icon(
                          Icons.date_range,
                          size: 18,
                        ),
                        label: Text(
                          vm.dueRange == null
                              ? 'Select range'
                              : '${Fmt.shortDate(vm.dueRange!.start)} – ${Fmt.shortDate(vm.dueRange!.end)}',
                        ),
                        onPressed: () async {
                          final r = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDateRange: vm.dueRange,
                          );

                          if (r != null) {
                            vm.setRangeFilter(r);
                            setSheet(() {});
                          }
                        },
                      ),
                      if (vm.dueRange != null)
                        ActionChip(
                          label: const Text('Clear'),
                          onPressed: () {
                            vm.setRangeFilter(null);
                            setSheet(() {});
                          },
                        ),
                    ],
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssignmentViewModel>();
    final courses = context.watch<CourseViewModel>();
    final list = vm.filtered;

    Widget body;

    if (vm.loading && vm.items.isEmpty) {
      body = const LoadingView();
    } else if (vm.error != null && vm.items.isEmpty) {
      body = ErrorState(
        message: vm.error!,
        onRetry: vm.load,
      );
    } else if (vm.items.isEmpty) {
      body = EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No assignments yet',
        message: 'Track deadlines, priorities and progress for every module.',
        actionLabel: 'Add assignment',
        onAction: _add,
      );
    } else if (list.isEmpty) {
      body = EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matches',
        message: 'No assignments match your search or filters.',
        actionLabel: 'Clear filters',
        onAction: () {
          vm.clearFilters();
          _search.clear();
        },
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, idx) {
          final a = list[idx];

          return AssignmentCard(
            assignment: a,
            courseName: courses.nameOf(a.courseId),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.assignmentDetail,
              arguments: a.localId,
            ),
            onToggleDone: () async {
              final err = await vm.changeStatus(
                a,
                a.isCompleted
                    ? AssignmentStatus.notStarted
                    : AssignmentStatus.completed,
              );

              if (err != null && context.mounted) {
                Notify.error(context, err);
              }
            },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: vm.setQuery,
                    decoration: InputDecoration(
                      hintText: 'Search assignments',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: vm.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                vm.setQuery('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Filters',
                  onPressed: _filterSheet,
                  icon: Badge(
                    isLabelVisible: vm.hasFilters,
                    smallSize: 8,
                    child: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'assignments_fab',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Assignment'),
      ),
    );
  }
}
