import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/core_exports.dart';
import '../../viewmodels/auth_view_model.dart';
import 'notify.dart';

/// Lets the user point the app at another backend (e.g. the PC's LAN IP when using a physical phone).
Future<void> showServerUrlDialog(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  final controller = TextEditingController(text: auth.apiConfig.baseUrl);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Server address'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'API base URL', hintText: 'http://192.168.1.10:5000/api'),
        ),
        const SizedBox(height: 10),
        const Text('Emulator: http://10.0.2.2:5000/api\nPhysical phone: use your computer\'s Wi-Fi IP, never localhost.',
            style: TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () {
            if (!ApiConfig.isValid(controller.text)) {
              Notify.error(ctx, 'Enter a valid http(s) URL');
              return;
            }
            Navigator.pop(ctx, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    await auth.setApiUrl(controller.text);
    if (context.mounted) Notify.success(context, 'Server address saved');
  }
}
