import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/assignment.dart';
import '../core/utils/date_utils.dart';
import 'entity_view_model.dart';

class AssignmentViewModel extends EntityViewModel<Assignment> {
  AssignmentViewModel(super.repo);

  String query = '';
  String? courseId;
  Priority? priority;
  AssignmentStatus? status; // may be "overdue" (derived)
  DateTimeRange? dueRange;

  bool get hasFilters => query.isNotEmpty || courseId != null || priority != null || status != null || dueRange != null;

  void setQuery(String q) {
    query = q;
    refreshView();
  }

  void setCourseFilter(String? v) {
    courseId = v;
    refreshView();
  }

  void setPriorityFilter(Priority? v) {
    priority = v;
    refreshView();
  }

  void setStatusFilter(AssignmentStatus? v) {
    status = v;
    refreshView();
  }

  void setRangeFilter(DateTimeRange? v) {
    dueRange = v;
    refreshView();
  }

  void clearFilters() {
    query = '';
    courseId = null;
    priority = null;
    status = null;
    dueRange = null;
    refreshView();
  }

  /// Search + course + priority + status + date-range filters, sorted by due date.
  List<Assignment> get filtered {
    final now = DateTime.now();
    final q = query.trim().toLowerCase();
    final list = items.where((a) {
      if (q.isNotEmpty && !(a.title.toLowerCase().contains(q) || a.description.toLowerCase().contains(q))) return false;
      if (courseId != null && a.courseId != courseId) return false;
      if (priority != null && a.priority != priority) return false;
      if (status != null && a.statusAt(now) != status) return false;
      final r = dueRange;
      if (r != null) {
        final d = Fmt.dayOnly(a.dueDate.toLocal());
        if (d.isBefore(Fmt.dayOnly(r.start)) || d.isAfter(Fmt.dayOnly(r.end))) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<Assignment> forCourse(String courseId) => items.where((a) => a.courseId == courseId).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// Quick status change from a card.
  Future<String?> changeStatus(Assignment a, AssignmentStatus s) => update(
        a.localId,
        Assignment.fields(
            courseId: a.courseId, title: a.title, description: a.description, dueDate: a.dueDate, priority: a.priority, status: s),
      );
}
