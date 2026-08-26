import 'package:chocolog/app/router.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Supabaseの認証コールバックをフレンド画面へリダイレクトする', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    final router = createAppRouter(preferences);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    router.go('chocolog://login-callback/?code=test-code');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/friends');
  });
}
