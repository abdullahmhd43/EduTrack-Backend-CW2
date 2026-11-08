import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../routes/app_routes.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/server_url_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthViewModel>().login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(tooltip: 'Server address', icon: const Icon(Icons.settings_ethernet), onPressed: () => showServerUrlDialog(context))],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.school_rounded, size: 44, color: t.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Welcome back', textAlign: TextAlign.center, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Log in to manage your courses and deadlines', textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  if (auth.error != null) _ErrorBanner(auth.error!),
                  AppTextField(
                    controller: _email,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _password,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) => Validators.required(v, 'Password'),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Log in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      auth.clearError();
                      Navigator.of(context).pushNamed(AppRoutes.register);
                    },
                    child: const Text("Don't have an account? Register"),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.error_outline, color: s.onErrorContainer),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: s.onErrorContainer))),
      ]),
    );
  }
}
