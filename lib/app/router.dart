import 'package:chocolog/features/equipment/presentation/equipment_selection_screen.dart';
import 'package:chocolog/features/history/presentation/history_screens.dart';
import 'package:chocolog/features/home/presentation/home_screen.dart';
import 'package:chocolog/features/friends/presentation/friends_screen.dart';
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
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reports',
              builder: (context, state) =>
                  ReportsScreen(preferences: onboardingPreferences),
              routes: [
                GoRoute(
                  path: 'history/:sessionId',
                  builder: (context, state) => HistoryDetailScreen(
                    sessionId: state.pathParameters['sessionId']!,
                    ownerId: state.uri.queryParameters['ownerId'],
                  ),
                ),
              ],
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
    GoRoute(path: '/history', redirect: (context, state) => '/reports'),
    GoRoute(
      path: '/history/:sessionId',
      redirect: (context, state) =>
          '/reports/history/${state.pathParameters['sessionId']}',
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
      path: '/settings/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    GoRoute(
      path: '/workout/equipment',
      builder: (context, state) => const EquipmentSelectionScreen(),
    ),
    GoRoute(
      path: '/workout/strength/:equipmentId',
      builder: (context, state) => StrengthEntryScreen(
        equipmentId: state.pathParameters['equipmentId']!,
        returnToHome: state.uri.queryParameters['returnTo'] == 'home',
        studioId: state.uri.queryParameters['studioId'],
      ),
    ),
    GoRoute(
      path: '/workout/bodyweight/:equipmentId',
      builder: (context, state) => StrengthEntryScreen(
        equipmentId: state.pathParameters['equipmentId']!,
        returnToHome: state.uri.queryParameters['returnTo'] == 'home',
        studioId: state.uri.queryParameters['studioId'],
      ),
    ),
    GoRoute(
      path: '/workout/cardio/:equipmentId',
      builder: (context, state) => CardioTimerScreen(
        equipmentId: state.pathParameters['equipmentId']!,
        returnToHome: state.uri.queryParameters['returnTo'] == 'home',
        studioId: state.uri.queryParameters['studioId'],
      ),
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
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
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
                selectedIcon: _SelectedNavigationIcon(
                  icon: Icons.home_outlined,
                ),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: _SelectedNavigationIcon(
                  icon: Icons.bar_chart_outlined,
                ),
                label: 'レポート',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: _SelectedNavigationIcon(
                  icon: Icons.settings_outlined,
                ),
                label: '設定',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedNavigationIcon extends StatelessWidget {
  const _SelectedNavigationIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
