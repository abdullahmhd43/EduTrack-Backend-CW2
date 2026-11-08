import 'package:edutrack/core/network/api_config.dart';
import 'package:edutrack/repositories/auth_repository.dart';
import 'package:edutrack/services/storage/secure_storage_service.dart';
import 'package:edutrack/viewmodels/auth_view_model.dart';
import 'package:edutrack/views/auth/login_screen.dart';
import 'package:edutrack/widgets/custom/month_calendar.dart';
import 'package:edutrack/widgets/custom/progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_api.dart';

AuthViewModel makeAuth() {
  final storage = SecureStorageService();
  return AuthViewModel(repo: AuthRepository(FakeApi(), storage), storage: storage, apiConfig: ApiConfig('http://fake/api'));
}

void main() {
  testWidgets('Login form validation shows errors for empty input', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthViewModel>.value(value: makeAuth(), child: const MaterialApp(home: LoginScreen())));
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Login form rejects an invalid email', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthViewModel>.value(value: makeAuth(), child: const MaterialApp(home: LoginScreen())));
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('Custom ProgressRing renders its centre widget', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: ProgressRing(value: 0.5, center: Text('50%'))))));
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('Custom MonthCalendar reports the tapped day', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MonthCalendar(
          focusedMonth: DateTime(2026, 11),
          selectedDay: DateTime(2026, 11, 1),
          eventCounts: const {'2026-11-10': 2},
          onDaySelected: (d) => tapped = d,
          onMonthChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.text('15'));
    expect(tapped, DateTime(2026, 11, 15));
  });
}
