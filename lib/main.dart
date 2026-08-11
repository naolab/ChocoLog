import 'package:chocolog/app/app.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:chocolog/features/settings/data/reminder_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderService.instance.initialize();
  final onboardingPreferences = await OnboardingPreferences.load();
  if (onboardingPreferences.reminderEnabled) {
    await ReminderService.instance.scheduleWeekly(
      weekdays: onboardingPreferences.reminderWeekdays,
      hour: onboardingPreferences.reminderHour,
      minute: onboardingPreferences.reminderMinute,
    );
  }
  runApp(
    ProviderScope(
      child: ChocoLogApp(onboardingPreferences: onboardingPreferences),
    ),
  );
}
