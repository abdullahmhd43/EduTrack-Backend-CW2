import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../viewmodels/assignment_view_model.dart';
import '../../viewmodels/course_view_model.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/course_card.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add() => Navigator.of(context).pushNamed(AppRoutes.courseForm);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CourseViewModel>();
    final assignments = context.watch<AssignmentViewModel>();
    final list = vm.filtered;

    Widget body;

    if (vm.loading && vm.items.isEmpty) {
      body = const LoadingView();
    } else if (vm.error != null && vm.items.isEmpty) {
      body = ErrorState(message: vm.error!, onRetry: vm.load);
    } else if (vm.items.isEmpty) {
      body = EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No courses yet',
        message:
            'Add your modules to start tracking assignments, study sessions and notes.',
        actionLabel: 'Add course',
        onAction: _add,
      );
    } else if (list.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No course matches "${vm.query.trim()}".',
        actionLabel: 'Clear search',
        onAction: () {
          _search.clear();
          vm.setQuery('');
        },
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => vm.load(silent: true),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, idx) {
            final c = list[idx];

            return CourseCard(
              course: c,
              assignmentCount: assignments.forCourse(c.localId).length,
              onTap: () => Navigator.of(context).pushNamed(
                AppRoutes.courseDetail,
                arguments: c.localId,
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          PopupMenuButton<CourseSort>(
            tooltip: 'Sort courses',
            icon: const Icon(Icons.sort),
            initialValue: vm.sort,
            onSelected: vm.setSort,
            itemBuilder: (_) => [
              for (final s in CourseSort.values)
                PopupMenuItem(
                  value: s,
                  child: Text(s.label),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (vm.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: vm.setQuery,
                decoration: InputDecoration(
                  hintText: 'Search courses',
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
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'courses_fab',
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Course'),
      ),
    );
  }
}
