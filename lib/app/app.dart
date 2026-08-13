import 'package:chocolog/app/router.dart';
import 'package:chocolog/app/theme.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChocoLogApp extends StatefulWidget {
  const ChocoLogApp({super.key, required this.onboardingPreferences});

  final OnboardingPreferences onboardingPreferences;

  @override
  State<ChocoLogApp> createState() => _ChocoLogAppState();
}

class _ChocoLogAppState extends State<ChocoLogApp> {
  late final GoRouter _router = createAppRouter(widget.onboardingPreferences);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'chocoLOG',
      debugShowCheckedModeBanner: false,
      theme: ChocoLogTheme.light,
      routerConfig: _router,
    );
  }
}
