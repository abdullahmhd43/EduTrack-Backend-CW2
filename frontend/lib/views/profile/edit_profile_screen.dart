import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/notify.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<AuthViewModel>().user?.name);
  late final _studentId = TextEditingController(text: context.read<AuthViewModel>().user?.studentId);
  late final _program = TextEditingController(text: context.read<AuthViewModel>().user?.program);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _studentId, _program]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await context.read<AuthViewModel>().updateProfile(name: _name.text, studentId: _studentId.text, program: _program.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      Notify.error(context, err);
    } else {
      Notify.success(context, 'Profile updated');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthViewModel>().user?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            AppTextField(controller: _name, label: 'Full name', icon: Icons.person_outline, validator: Validators.name, textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            AppTextField(controller: _studentId, label: 'Student ID', icon: Icons.badge_outlined, validator: (v) => Validators.maxLen(v, 30, 'Student ID'), textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            AppTextField(controller: _program, label: 'Programme', icon: Icons.school_outlined, validator: (v) => Validators.maxLen(v, 100, 'Programme')),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Email (cannot be changed)', prefixIcon: Icon(Icons.email_outlined)),
              child: Text(email),
            ),
            const SizedBox(height: 8),
            Text('Profile changes need an internet connection.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ]),
        ),
      ),
    );
  }
}
