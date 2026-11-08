import '../models/note.dart';
import 'entity_view_model.dart';

class NoteViewModel extends EntityViewModel<Note> {
  NoteViewModel(super.repo);

  String query = '';
  String? courseId;

  void setQuery(String q) {
    query = q;
    refreshView();
  }

  void setCourse(String? id) {
    courseId = id;
    refreshView();
  }

  List<Note> get filtered {
    final q = query.trim().toLowerCase();
    final list = items.where((n) {
      if (courseId != null && n.courseId != courseId) return false;
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
}
