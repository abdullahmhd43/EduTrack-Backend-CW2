import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/note_view_model.dart';
import '../../widgets/common/states.dart';
import '../../widgets/custom/note_card.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NoteViewModel>();
    final courses = context.watch<CourseViewModel>();
    final list = vm.filtered;

    Widget body;

    if (vm.loading && vm.items.isEmpty) {
      body = const LoadingView();
    } else if (vm.items.isEmpty) {
      body = EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: 'No notes yet',
        message:
            'Capture lecture notes, formulas and ideas. They work offline too.',
        actionLabel: 'Write a note',
        onAction: () => Navigator.of(context).pushNamed(AppRoutes.noteForm),
      );
    } else if (list.isEmpty) {
      body = const EmptyState(
        icon: Icons.search_off,
        title: 'No matching notes',
        message: 'Try a different search or course filter.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final n = list[i];

          return NoteCard(
            note: n,
            courseName: n.courseId == null ? null : courses.nameOf(n.courseId),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.noteForm,
              arguments: n,
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: vm.setQuery,
              decoration: InputDecoration(
                hintText: 'Search notes',
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
          if (courses.items.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: vm.courseId == null,
                      onSelected: (_) => vm.setCourse(null),
                    ),
                  ),
                  for (final c in courses.sorted)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.code),
                        selected: vm.courseId == c.localId,
                        onSelected: (v) => vm.setCourse(v ? c.localId : null),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_fab',
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.noteForm),
        icon: const Icon(Icons.add),
        label: const Text('Note'),
      ),
    );
  }
}
