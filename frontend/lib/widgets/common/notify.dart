import 'package:flutter/material.dart';

/// Consistent success / error feedback.
class Notify {
  Notify._();

  static void success(BuildContext context, String message) => _show(context, message, Icons.check_circle, const Color(0xFF2E7D32));
  static void error(BuildContext context, String message) => _show(context, message, Icons.error, const Color(0xFFC62828));
  static void info(BuildContext context, String message) => _show(context, message, Icons.info, const Color(0xFF1565C0));

  static void _show(BuildContext context, String message, IconData icon, Color color) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      backgroundColor: color,
      content: Row(children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
      ]),
    ));
  }
}
