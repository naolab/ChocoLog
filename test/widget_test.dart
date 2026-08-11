import 'package:chocolog/app/app.dart';
import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('初回起動でオンボーディングを完了できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await OnboardingPreferences.load();

    await tester.pumpWidget(
      ProviderScope(child: ChocoLogApp(onboardingPreferences: preferences)),
    );
    await tester.pumpAndSettle();

    expect(find.text('いつものトレーニングを\nかんたんに記録'), findsOneWidget);
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('週2回　おすすめ'), findsOneWidget);
    await tester.tap(find.text('週3回'));
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    expect(find.text('よく行く店舗'), findsOneWidget);
    await tester.tap(find.text('今は設定しない'));
    await tester.pumpAndSettle();

    expect(find.text('リマインダー'), findsOneWidget);
    await tester.tap(find.text('リマインダーを設定'));
    await tester.pump();
    await tester.tap(find.text('設定を保存して始める'));
    await tester.pumpAndSettle();

    expect(find.text('トレーニングを始める'), findsOneWidget);
    expect(find.text('今週 0 / 3回'), findsOneWidget);
    expect(preferences.isCompleted, isTrue);
    expect(preferences.weeklyTarget, 3);
    expect(preferences.reminderEnabled, isTrue);
    expect(preferences.reminderWeekdays, [DateTime.tuesday, DateTime.saturday]);
    expect(preferences.reminderHour, 19);
    expect(preferences.reminderMinute, 0);
  });

  testWidgets('完了済みならホームから通常4タブへ移動できる', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: ChocoLogApp(onboardingPreferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('トレーニングを始める'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('トレーニングを始める'));
    await tester.pumpAndSettle();
    expect(find.text('今回の店舗'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.text('トレーニングの記録がここに表示されます'), findsOneWidget);

    await tester.tap(find.text('レポート'));
    await tester.pumpAndSettle();
    expect(find.text('記録を続けると週・月の成果を確認できます'), findsOneWidget);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('目標回数や通知を設定できます'), findsOneWidget);
  });
}
