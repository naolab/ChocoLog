import 'package:chocolog/app/app.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final onboardingPreferences = await OnboardingPreferences.load();
  runApp(
    ProviderScope(
      child: ChocoLogApp(onboardingPreferences: onboardingPreferences),
    ),
  );
}
