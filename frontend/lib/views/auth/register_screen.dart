import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/server_url_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _studentId = TextEditingController();
  final _program = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _studentId, _program, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthViewModel>();
    final ok = await auth.register(
        name: _name.text, email: _email.text, password: _password.text, studentId: _studentId.text, program: _program.text);
    if (ok && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        actions: [IconButton(tooltip: 'Server address', icon: const Icon(Icons.settings_ethernet), onPressed: () => showServerUrlDialog(context))],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Join EduTrack', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Your data is private and stays linked to your account.'),
              const SizedBox(height: 20),
              if (auth.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: t.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text(auth.error!, style: TextStyle(color: t.colorScheme.onErrorContainer)),
                ),
              AppTextField(controller: _name, label: 'Full name', icon: Icons.person_outline, textInputAction: TextInputAction.next, validator: Validators.name, errorText: auth.fieldErrors['name']),
              const SizedBox(height: 14),
              AppTextField(controller: _email, label: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: Validators.email, errorText: auth.fieldErrors['email']),
              const SizedBox(height: 14),
              AppTextField(controller: _studentId, label: 'Student ID (optional)', icon: Icons.badge_outlined, textInputAction: TextInputAction.next, validator: (v) => Validators.maxLen(v, 30, 'Student ID')),
              const SizedBox(height: 14),
              AppTextField(controller: _program, label: 'Programme (optional)', icon: Icons.school_outlined, textInputAction: TextInputAction.next, validator: (v) => Validators.maxLen(v, 100, 'Programme')),
              const SizedBox(height: 14),
              AppTextField(controller: _password, label: 'Password', icon: Icons.lock_outline, obscure: true, textInputAction: TextInputAction.next, validator: Validators.password, errorText: auth.fieldErrors['password']),
              const SizedBox(height: 14),
              AppTextField(controller: _confirm, label: 'Confirm password', icon: Icons.lock_outline, obscure: true, textInputAction: TextInputAction.done, validator: (v) => Validators.confirmPassword(v, _password.text)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.loading ? null : _submit,
                child: auth.loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Create account'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
