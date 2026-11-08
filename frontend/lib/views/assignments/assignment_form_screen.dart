import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../models/assignment.dart';
import '../../viewmodels/assignment_view_model.dart';
import '../../viewmodels/course_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/pickers.dart';

class AssignmentFormScreen extends StatefulWidget {
  final Assignment? assignment;
  final String? initialCourseId;
  const AssignmentFormScreen({super.key, this.assignment, this.initialCourseId});

  @override
  State<AssignmentFormScreen> createState() => _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends State<AssignmentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.assignment?.title);
  late final _description = TextEditingController(text: widget.assignment?.description);
  late String? _courseId = widget.assignment?.courseId ?? widget.initialCourseId;
  late DateTime _due = widget.assignment?.dueDate.toLocal() ?? DateTime.now().add(const Duration(days: 7));
  late Priority _priority = widget.assignment?.priority ?? Priority.medium;
  late AssignmentStatus _status = widget.assignment?.storedStatus ?? AssignmentStatus.notStarted;
  bool _saving = false;

  bool get _editing => widget.assignment != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (t != null) setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vm = context.read<AssignmentViewModel>();
    final fields = Assignment.fields(
        courseId: _courseId!, title: _title.text, description: _description.text, dueDate: _due, priority: _priority, status: _status);
    final err = _editing ? await vm.update(widget.assignment!.localId, fields) : await vm.create(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, _editing ? 'Assignment updated' : 'Assignment added');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseViewModel>().sorted;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit assignment' : 'Add assignment')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AppTextField(controller: _title, label: 'Title', icon: Icons.title, textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Title') ?? Validators.maxLen(v, 150, 'Title')),
            const SizedBox(height: 14),
            SelectField<String>(
              label: 'Course',
              icon: Icons.menu_book_outlined,
              value: _courseId,
              items: [for (final c in courses) SelectItem(c.localId, '${c.code} · ${c.name}')],
              onChanged: (v) => setState(() => _courseId = v),
              validator: (v) => v == null ? 'Select a course' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _description, label: 'Description', icon: Icons.notes, maxLines: 3,
                validator: (v) => Validators.maxLen(v, 2000, 'Description')),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: DateField(label: 'Due date', value: _due, onChanged: (d) => setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute)))),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.schedule)),
                    child: Text(Fmt.time(_due.hour, _due.minute)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            SelectField<Priority>(
              label: 'Priority',
              icon: Icons.flag_outlined,
              value: _priority,
              items: [for (final p in Priority.values) SelectItem(p, p.label)],
              onChanged: (v) => setState(() => _priority = v ?? Priority.medium),
            ),
            const SizedBox(height: 14),
            SelectField<AssignmentStatus>(
              label: 'Status',
              icon: Icons.timelapse,
              value: _status,
              items: [for (final s in [AssignmentStatus.notStarted, AssignmentStatus.inProgress, AssignmentStatus.completed]) SelectItem(s, s.label)],
              onChanged: (v) => setState(() => _status = v ?? AssignmentStatus.notStarted),
            ),
            const SizedBox(height: 6),
            Text('Overdue is applied automatically when the due date passes and the assignment is not completed.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_editing ? 'Save changes' : 'Add assignment'),
            ),
          ]),
        ),
      ),
    );
  }
}
