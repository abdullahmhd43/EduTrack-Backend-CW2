import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/custom/sync_status_banner.dart';
import '../assignments/assignments_screen.dart';
import '../courses/courses_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../planner/planner_screen.dart';
import 'more_screen.dart';
import 'shell_nav.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShellNav(),
      child: Consumer<ShellNav>(
        builder: (context, nav, _) => Scaffold(
          body: Column(children: [
            SafeArea(bottom: false, child: const SyncStatusBanner()),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: IndexedStack(index: nav.index, children: const [
                  DashboardScreen(),
                  CoursesScreen(),
                  AssignmentsScreen(),
                  PlannerScreen(),
                  MoreScreen(),
                ]),
              ),
            ),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: nav.index,
            onDestinationSelected: nav.go,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Courses'),
              NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tasks'),
              NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Planner'),
              NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'More'),
            ],
          ),
        ),
      ),
    );
  }
}
