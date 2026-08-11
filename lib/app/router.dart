import 'package:chocolog/features/equipment/presentation/equipment_selection_screen.dart';
import 'package:chocolog/features/history/presentation/history_screens.dart';
import 'package:chocolog/features/home/presentation/home_screen.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:chocolog/features/onboarding/presentation/onboarding_screen.dart';
import 'package:chocolog/features/reports/presentation/reports_screen.dart';
import 'package:chocolog/features/settings/data/reminder_service.dart';
import 'package:chocolog/features/settings/presentation/settings_screen.dart';
import 'package:chocolog/features/studios/presentation/studio_search_screen.dart';
import 'package:chocolog/features/workout/presentation/strength_entry_screen.dart';
import 'package:chocolog/features/workout/presentation/cardio_timer_screen.dart';
import 'package:chocolog/features/workout/presentation/studio_selection_screen.dart';
import 'package:chocolog/features/workout/presentation/workout_session_screens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(
  OnboardingPreferences onboardingPreferences,
) => GoRouter(
  initialLocation: onboardingPreferences.isCompleted ? '/home' : '/onboarding',
  redirect: (context, state) {
    final isOnboarding = state.matchedLocation == '/onboarding';
    if (!onboardingPreferences.isCompleted) {
      return isOnboarding ? null : '/onboarding';
    }
    return isOnboarding ? '/home' : null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onCompleted: (settings) async {
          var reminderEnabled = settings.reminderEnabled;
          if (reminderEnabled && ReminderService.instance.isSupported) {
            reminderEnabled = await ReminderService.instance.scheduleWeekly(
              weekdays: settings.reminderWeekdays,
              hour: settings.reminderHour,
              minute: settings.reminderMinute,
              requestPermission: true,
            );
          }
          await onboardingPreferences.complete(
            OnboardingSettings(
              weeklyTarget: settings.weeklyTarget,
              reminderEnabled: reminderEnabled,
              reminderWeekdays: settings.reminderWeekdays,
              reminderHour: settings.reminderHour,
              reminderMinute: settings.reminderMinute,
            ),
          );
          if (context.mounted) context.go('/home');
        },
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) =>
                  HomeScreen(preferences: onboardingPreferences),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
              routes: [
                GoRoute(
                  path: ':sessionId',
                  builder: (context, state) => HistoryDetailScreen(
                    sessionId: state.pathParameters['sessionId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) =>
                  ReportsScreen(preferences: onboardingPreferences),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  SettingsScreen(preferences: onboardingPreferences),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/workout/studio',
      builder: (context, state) => const StudioSelectionScreen(),
    ),
    GoRoute(
      path: '/workout/studio/search',
      builder: (context, state) => const StudioSearchScreen(selectable: true),
    ),
    GoRoute(
      path: '/settings/studios',
      builder: (context, state) => const StudioSearchScreen(),
    ),
    GoRoute(
      path: '/workout/equipment',
      builder: (context, state) => const EquipmentSelectionScreen(),
    ),
    GoRoute(
      path: '/workout/strength/:equipmentId',
      builder: (context, state) => StrengthEntryScreen(
        equipmentId: state.pathParameters['equipmentId']!,
      ),
    ),
    GoRoute(
      path: '/workout/bodyweight/:equipmentId',
      builder: (context, state) => StrengthEntryScreen(
        equipmentId: state.pathParameters['equipmentId']!,
      ),
    ),
    GoRoute(
      path: '/workout/cardio/:equipmentId',
      builder: (context, state) =>
          CardioTimerScreen(equipmentId: state.pathParameters['equipmentId']!),
    ),
    GoRoute(
      path: '/workout/session',
      builder: (context, state) => const WorkoutSessionScreen(),
    ),
    GoRoute(
      path: '/workout/review',
      builder: (context, state) => const WorkoutReviewScreen(),
    ),
    GoRoute(
      path: '/workout/complete/:sessionId',
      builder: (context, state) =>
          WorkoutCompleteScreen(sessionId: state.pathParameters['sessionId']!),
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '履歴',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'レポート',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
