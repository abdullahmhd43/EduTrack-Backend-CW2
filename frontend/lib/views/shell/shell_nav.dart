import 'package:flutter/foundation.dart';

/// Tiny ViewModel for the bottom navigation index (lets the dashboard jump to other tabs).
class ShellNav extends ChangeNotifier {
  int index = 0;
  void go(int i) {
    if (i == index) return;
    index = i;
    notifyListeners();
  }
}
