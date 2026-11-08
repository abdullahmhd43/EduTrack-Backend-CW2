import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../models/academic_event.dart';
import '../../viewmodels/event_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/notify.dart';
import '../../widgets/common/pickers.dart';

class EventFormScreen extends StatefulWidget {
  final AcademicEvent? event;
  final DateTime? initialDay;
  const EventFormScreen({super.key, this.event, this.initialDay});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _location = TextEditingController(text: widget.event?.location);
  late final _description = TextEditingController(text: widget.event?.description);
  late EventType _type = widget.event?.type ?? EventType.exam;
  late DateTime _day = widget.event?.day ?? widget.initialDay ?? Fmt.dayOnly(DateTime.now());
  late String _start = widget.event?.startTime ?? '09:00';
  late String _end = widget.event?.endTime ?? '';
  bool _saving = false;

  bool get _editing => widget.event != null;

  @override
  void dispose() {
    for (final c in [_title, _location, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vm = context.read<EventViewModel>();
    final fields = AcademicEvent.fields(
        title: _title.text, type: _type, date: Fmt.ymd(_day), startTime: _start, endTime: _end, location: _location.text, description: _description.text);
    final err = _editing ? await vm.update(widget.event!.localId, fields) : await vm.create(fields);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, _editing ? 'Event updated' : 'Event added');
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Delete event?', message: '"${widget.event!.title}" will be removed.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    final err = await context.read<EventViewModel>().delete(widget.event!.localId);
    if (!mounted) return;
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, 'Event deleted');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit event' : 'Add event'),
        actions: [if (_editing) IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            SelectField<EventType>(
              label: 'Type',
              icon: Icons.category_outlined,
              value: _type,
              items: const [
                SelectItem(EventType.exam, 'Examination', Icons.assignment_late_outlined),
                SelectItem(EventType.classSchedule, 'Class schedule', Icons.school_outlined),
                SelectItem(EventType.event, 'Academic event', Icons.event_outlined),
              ],
              onChanged: (v) => setState(() => _type = v ?? EventType.event),
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _title, label: 'Title', icon: Icons.title, textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Title') ?? Validators.maxLen(v, 150, 'Title')),
            const SizedBox(height: 14),
            DateField(label: 'Date', value: _day, onChanged: (d) => setState(() => _day = Fmt.dayOnly(d))),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TimeField(label: 'Start time', value: _start, onChanged: (v) => setState(() => _start = v), validator: (v) => Validators.required(v, 'Start time'))),
              const SizedBox(width: 10),
              Expanded(
                child: TimeField(
                  label: 'End (optional)',
                  value: _end,
                  onChanged: (v) => setState(() => _end = v),
                  validator: (v) => (_end.isEmpty) ? null : Validators.timeOrder(_start, _end),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            AppTextField(controller: _location, label: 'Location', icon: Icons.place_outlined, textInputAction: TextInputAction.next, validator: (v) => Validators.maxLen(v, 150, 'Location')),
            const SizedBox(height: 14),
            AppTextField(controller: _description, label: 'Description', icon: Icons.notes, maxLines: 3, validator: (v) => Validators.maxLen(v, 1000, 'Description')),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_editing ? 'Save changes' : 'Add event'),
            ),
          ]),
        ),
      ),
    );
  }
}
