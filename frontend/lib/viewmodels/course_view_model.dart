import '../models/course.dart';
import 'entity_view_model.dart';

enum CourseSort { nameAsc, codeAsc, newestFirst, endingSoon }

extension CourseSortX on CourseSort {
  String get label {
    switch (this) {
      case CourseSort.nameAsc:
        return 'Name (A-Z)';
      case CourseSort.codeAsc:
        return 'Course code';
      case CourseSort.newestFirst:
        return 'Recently added';
      case CourseSort.endingSoon:
        return 'Ending soonest';
    }
  }
}

class CourseViewModel extends EntityViewModel<Course> {
  CourseViewModel(super.repo);

  String query = '';
  CourseSort sort = CourseSort.nameAsc;

  void setQuery(String q) {
    query = q;
    refreshView();
  }

  void setSort(CourseSort s) {
    sort = s;
    refreshView();
  }

  /// All courses, A-Z (used by dropdowns and statistics).
  List<Course> get sorted => [...items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Courses matching the search text (name, code, lecturer, description), in the chosen order.
  List<Course> get filtered {
    final q = query.trim().toLowerCase();
    final list = items.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.code.toLowerCase().contains(q) ||
          c.lecturer.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
    switch (sort) {
      case CourseSort.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case CourseSort.codeAsc:
        list.sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));
      case CourseSort.newestFirst:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case CourseSort.endingSoon:
        list.sort((a, b) => a.endDate.compareTo(b.endDate));
    }
    return list;
  }

  String nameOf(String? courseId) => byId(courseId)?.name ?? 'Unknown course';
  String codeOf(String? courseId) => byId(courseId)?.code ?? '';
}
