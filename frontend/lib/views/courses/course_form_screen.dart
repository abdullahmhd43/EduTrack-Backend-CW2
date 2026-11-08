import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../models/course.dart';
import '../../viewmodels/course_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/pickers.dart';

class CourseFormScreen extends StatefulWidget {
  final Course? course;
  const CourseFormScreen({super.key, this.course});

  @override
  State<CourseFormScreen> createState() => _CourseFormScreenState();
}

class _CourseFormScreenState extends State<CourseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name);
  late final _code = TextEditingController(text: widget.course?.code);
  late final _lecturer = TextEditingController(text: widget.course?.lecturer);
  late final _description = TextEditingController(text: widget.course?.description);
  late DateTime _start = widget.course?.startDate.toLocal() ?? Fmt.dayOnly(DateTime.now());
  late DateTime _end = widget.course?.endDate.toLocal() ?? Fmt.dayOnly(DateTime.now().add(const Duration(days: 120)));
  bool _saving = false;

  bool get _editing => widget.course != null;

  @override
  void dispose() {
    for (final c in [_name, _code, _lecturer, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vm = context.read<CourseViewModel>();
    final fields = Course.fields(
        name: _name.text, code: _code.text, lecturer: _lecturer.text, description: _description.text, startDate: _start, endDate: _end);
    final err = _editing ? await vm.update(widget.course!.localId, fields) : await vm.create(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, _editing ? 'Course updated' : 'Course added');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit course' : 'Add course')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AppTextField(controller: _name, label: 'Course name', icon: Icons.menu_book_outlined, textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Course name') ?? Validators.maxLen(v, 100, 'Course name')),
            const SizedBox(height: 14),
            AppTextField(controller: _code, label: 'Course code', icon: Icons.tag, hint: 'e.g. CI6330', textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Course code') ?? Validators.maxLen(v, 20, 'Course code')),
            const SizedBox(height: 14),
            AppTextField(controller: _lecturer, label: 'Lecturer name', icon: Icons.person_outline, textInputAction: TextInputAction.next,
                validator: (v) => Validators.maxLen(v, 100, 'Lecturer name')),
            const SizedBox(height: 14),
            AppTextField(controller: _description, label: 'Description', icon: Icons.notes, maxLines: 3,
                validator: (v) => Validators.maxLen(v, 1000, 'Description')),
            const SizedBox(height: 14),
            DateField(label: 'Start date', value: _start, onChanged: (d) => setState(() => _start = d)),
            const SizedBox(height: 14),
            DateField(
              label: 'End date',
              value: _end,
              onChanged: (d) => setState(() => _end = d),
              validator: (_) => Validators.dateOrder(_start, _end),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_editing ? 'Save changes' : 'Add course'),
            ),
          ]),
        ),
      ),
    );
  }
}
