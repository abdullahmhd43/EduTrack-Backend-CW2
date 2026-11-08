import 'package:flutter/material.dart';

import 'app.dart';
import 'providers/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = AppDependencies();
  runApp(EduTrackApp(deps: deps));
  // Start connectivity/sync and restore the session after the first frame (splash is shown meanwhile).
  await Future.wait([deps.start(), Future<void>.delayed(const Duration(milliseconds: 1200))]);
}
