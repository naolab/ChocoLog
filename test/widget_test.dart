import 'package:chocolog/app/app.dart';
import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/onboarding/data/onboarding_preferences.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('初回起動でオンボーディングを完了できる', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    expect(find.text('今日のトレーニング'), findsOneWidget);
    expect(find.text('完了したトレーニングはまだありません'), findsOneWidget);
    expect(preferences.isCompleted, isTrue);
    expect(preferences.weeklyTarget, 3);
    expect(preferences.reminderEnabled, isTrue);
    expect(preferences.reminderWeekdays, [DateTime.tuesday, DateTime.saturday]);
    expect(preferences.reminderHour, 19);
    expect(preferences.reminderMinute, 0);
  });

  testWidgets('完了済みならホームから通常3タブへ移動できる', (tester) async {
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

    await tester.tap(find.text('レポート'));
    await tester.pumpAndSettle();
    expect(find.text('トレーニングの記録がここに表示されます'), findsOneWidget);
    await tester.tap(find.text('分析'));
    await tester.pumpAndSettle();
    expect(find.text('この期間の記録はありません'), findsOneWidget);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('週の目標回数'), findsOneWidget);
    expect(find.text('週間リマインダー'), findsOneWidget);

    await tester.tap(find.text('週2回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('週3回').last);
    await tester.pumpAndSettle();
    expect(preferences.weeklyTarget, 3);

    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(find.text('今日のトレーニング'), findsOneWidget);
  });

  testWidgets('レポートの履歴から同じセットを開始できる', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await EquipmentRepository(database).seedDefaults();
    final repository = WorkoutRepository(database);
    final previous = await repository.startSession();
    await repository.addExerciseSets(
      sessionId: previous.id,
      equipmentId: 'chest-press',
      sets: const [
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 25, reps: 12),
      ],
    );
    await repository.completeSession(previous.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: ChocoLogApp(onboardingPreferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日の記録'), findsOneWidget);
    expect(find.textContaining('チェストプレス'), findsOneWidget);
    await tester.tap(find.text('レポート'));
    await tester.pumpAndSettle();
    final sessionTitle = find.textContaining('1種目・2セット');
    await tester.scrollUntilVisible(
      sessionTitle,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    final sessionTile = find.ancestor(
      of: sessionTitle,
      matching: find.byType(ListTile),
    );
    await tester.pumpAndSettle();
    await tester.tap(sessionTile);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('このメニューを複製'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このメニューを複製'));
    await tester.pumpAndSettle();

    expect(find.text('今日の記録'), findsOneWidget);
    expect(find.textContaining('20kg × 15回'), findsOneWidget);
    expect(find.textContaining('25kg × 12回'), findsOneWidget);
    final active = await repository.getActiveSession();
    expect(active, isNotNull);
    expect(
      await repository.getSessionSets(
        sessionId: active!.id,
        equipmentId: 'chest-press',
      ),
      hasLength(2),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
