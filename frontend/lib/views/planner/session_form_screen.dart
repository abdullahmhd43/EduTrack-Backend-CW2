import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../models/study_session.dart';
import '../../viewmodels/course_view_model.dart';
import '../../viewmodels/study_session_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/pickers.dart';

class SessionFormScreen extends StatefulWidget {
  final StudySession? session;
  final DateTime? initialDay;
  const SessionFormScreen({super.key, this.session, this.initialDay});

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _topic = TextEditingController(text: widget.session?.topic);
  late final _description = TextEditingController(text: widget.session?.description);
  late String? _courseId = widget.session?.courseId;
  late DateTime _day = widget.session?.day ?? widget.initialDay ?? Fmt.dayOnly(DateTime.now());
  late String _start = widget.session?.startTime ?? '09:00';
  late String _end = widget.session?.endTime ?? '10:00';
  bool _saving = false;

  bool get _editing => widget.session != null;

  @override
  void dispose() {
    _topic.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vm = context.read<StudySessionViewModel>();
    final fields = StudySession.fields(
        courseId: _courseId!, topic: _topic.text, description: _description.text, date: Fmt.ymd(_day), startTime: _start, endTime: _end,
        completed: widget.session?.completed ?? false);
    final err = _editing ? await vm.update(widget.session!.localId, fields) : await vm.create(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, _editing ? 'Session updated' : 'Session planned');
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Delete session?', message: 'This study session will be removed.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    final err = await context.read<StudySessionViewModel>().delete(widget.session!.localId);
    if (!mounted) return;
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, 'Session deleted');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseViewModel>().sorted;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit study session' : 'Plan study session'),
        actions: [if (_editing) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            SelectField<String>(
              label: 'Course',
              icon: Icons.menu_book_outlined,
              value: _courseId,
              items: [for (final c in courses) SelectItem(c.localId, '${c.code} · ${c.name}')],
              onChanged: (v) => setState(() => _courseId = v),
              validator: (v) => v == null ? 'Select a course' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _topic, label: 'Study topic', icon: Icons.lightbulb_outline, textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Topic') ?? Validators.maxLen(v, 150, 'Topic')),
            const SizedBox(height: 14),
            DateField(label: 'Study date', value: _day, onChanged: (d) => setState(() => _day = Fmt.dayOnly(d))),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TimeField(label: 'Start time', value: _start, onChanged: (v) => setState(() => _start = v), validator: (v) => Validators.required(v, 'Start time'))),
              const SizedBox(width: 10),
              Expanded(child: TimeField(label: 'End time', value: _end, onChanged: (v) => setState(() => _end = v), validator: (v) => Validators.required(v, 'End time') ?? Validators.timeOrder(_start, _end))),
            ]),
            const SizedBox(height: 14),
            AppTextField(controller: _description, label: 'Description', icon: Icons.notes, maxLines: 3, validator: (v) => Validators.maxLen(v, 1000, 'Description')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_editing ? 'Save changes' : 'Add session'),
            ),
          ]),
        ),
      ),
    );
  }
}
