import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../models/note.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/note_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/pickers.dart';

class NoteFormScreen extends StatefulWidget {
  final Note? note;
  const NoteFormScreen({super.key, this.note});

  @override
  State<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends State<NoteFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.note?.title);
  late final _content = TextEditingController(text: widget.note?.content);
  late String? _courseId = widget.note?.courseId;
  bool _saving = false;

  bool get _editing => widget.note != null;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vm = context.read<NoteViewModel>();
    final fields = Note.fields(courseId: _courseId, title: _title.text, content: _content.text);
    final err = _editing ? await vm.update(widget.note!.localId, fields) : await vm.create(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, _editing ? 'Note updated' : 'Note saved');
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Delete note?', message: '"${widget.note!.title}" will be removed.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    final err = await context.read<NoteViewModel>().delete(widget.note!.localId);
    if (!mounted) return;
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, 'Note deleted');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseViewModel>().sorted;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit note' : 'New note'),
        actions: [if (_editing) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AppTextField(controller: _title, label: 'Title', icon: Icons.title, textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Title') ?? Validators.maxLen(v, 150, 'Title')),
            const SizedBox(height: 14),
            SelectField<String>(
              label: 'Course (optional)',
              icon: Icons.menu_book_outlined,
              value: _courseId,
              allowClear: true,
              placeholder: 'No course',
              items: [for (final c in courses) SelectItem(c.localId, '${c.code} · ${c.name}')],
              onChanged: (v) => setState(() => _courseId = v),
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _content, label: 'Content', icon: Icons.notes, maxLines: 12,
                validator: (v) => Validators.required(v, 'Content') ?? Validators.maxLen(v, 20000, 'Content')),
            if (_editing) ...[
              const SizedBox(height: 8),
              Text('Created ${Fmt.dateTime(widget.note!.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_editing ? 'Save changes' : 'Save note'),
            ),
          ]),
        ),
      ),
    );
  }
}
