import 'package:chocolog/app/app.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ホーム・レポート・フレンド・設定の主要導線を開ける', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    await tester.pumpWidget(ChocoLogApp(onboardingPreferences: preferences));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const Key('home-wordmark')), findsOneWidget);
    expect(find.text('器具を選んで記録'), findsOneWidget);

    await tester.tap(find.text('レポート').last);
    await tester.pumpAndSettle();
    expect(find.text('履歴'), findsOneWidget);

    await tester.tap(find.text('フレンド'));
    await tester.pumpAndSettle();
    expect(find.text('友人のトレーニング履歴を見たり、\n自分の履歴を共有できます'), findsOneWidget);

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    expect(find.text('トレーニング設定'), findsOneWidget);
  });
}
