import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';

/// Form field that opens the date picker. Validates through the normal Form mechanism.
class DateField extends FormField<DateTime> {
  DateField({
    super.key,
    required String label,
    DateTime? value,
    required ValueChanged<DateTime> onChanged,
    super.validator,
    DateTime? firstDate,
    DateTime? lastDate,
    IconData icon = Icons.calendar_today_outlined,
  }) : super(
          initialValue: value,
          builder: (state) {
            final first = firstDate ?? DateTime(2000);
            final last = lastDate ?? DateTime(2100);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                var initial = state.value ?? DateTime.now();
                if (initial.isBefore(first)) initial = first;
                if (initial.isAfter(last)) initial = last;
                final picked = await showDatePicker(context: state.context, initialDate: initial, firstDate: first, lastDate: last);
                if (picked != null) {
                  state.didChange(picked);
                  onChanged(picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), errorText: state.errorText),
                child: Text(state.value == null ? 'Select date' : Fmt.pretty(state.value!),
                    style: state.value == null ? TextStyle(color: Theme.of(state.context).hintColor) : null),
              ),
            );
          },
        );
}

/// Time field working with "HH:mm" strings (the format used in SQLite and the API).
class TimeField extends FormField<String> {
  TimeField({
    super.key,
    required String label,
    String? value,
    required ValueChanged<String> onChanged,
    super.validator,
    IconData icon = Icons.schedule,
  }) : super(
          initialValue: (value == null || value.isEmpty) ? null : value,
          builder: (state) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                TimeOfDay initial = TimeOfDay.now();
                final v = state.value;
                if (v != null && v.contains(':')) {
                  final p = v.split(':');
                  initial = TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
                }
                final picked = await showTimePicker(context: state.context, initialTime: initial);
                if (picked != null) {
                  final s = Fmt.time(picked.hour, picked.minute);
                  state.didChange(s);
                  onChanged(s);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), errorText: state.errorText),
                child: Text(state.value ?? 'Select time', style: state.value == null ? TextStyle(color: Theme.of(state.context).hintColor) : null),
              ),
            );
          },
        );
}

class SelectItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  const SelectItem(this.value, this.label, [this.icon]);
}

/// Custom select field (bottom sheet list) used instead of a dropdown for better touch targets.
class SelectField<T> extends FormField<T> {
  SelectField({
    super.key,
    required String label,
    required List<SelectItem<T>> items,
    T? value,
    required ValueChanged<T?> onChanged,
    super.validator,
    IconData? icon,
    bool allowClear = false,
    String placeholder = 'Select',
  }) : super(
          initialValue: value,
          builder: (state) {
            String? currentLabel;
            for (final i in items) {
              if (i.value == state.value) currentLabel = i.label;
            }
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final result = await showModalBottomSheet<_Picked<T>>(
                  context: state.context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (allowClear)
                          ListTile(
                            leading: const Icon(Icons.clear),
                            title: const Text('None'),
                            onTap: () => Navigator.pop(ctx, _Picked<T>(null)),
                          ),
                        for (final i in items)
                          ListTile(
                            leading: i.icon == null ? null : Icon(i.icon),
                            title: Text(i.label),
                            trailing: i.value == state.value ? const Icon(Icons.check) : null,
                            onTap: () => Navigator.pop(ctx, _Picked<T>(i.value)),
                          ),
                      ],
                    ),
                  ),
                );
                if (result != null) {
                  state.didChange(result.value);
                  onChanged(result.value);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: icon == null ? null : Icon(icon),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  errorText: state.errorText,
                ),
                child: Text(currentLabel ?? placeholder,
                    style: currentLabel == null ? TextStyle(color: Theme.of(state.context).hintColor) : null),
              ),
            );
          },
        );
}

class _Picked<T> {
  final T? value;
  _Picked(this.value);
}
