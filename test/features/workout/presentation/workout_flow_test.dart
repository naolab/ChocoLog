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
  testWidgets('器具を選び筋トレと自重のセットを保存できる', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await EquipmentRepository(database).seedDefaults();
    var current = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final repository = WorkoutRepository(database, now: () => current);
    final previousSession = await repository.startSession();
    await repository.addExerciseSets(
      sessionId: previousSession.id,
      equipmentId: 'chest-press',
      sets: const [
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 20, reps: 15),
      ],
    );
    await repository.completeSession(previousSession.id);
    current = DateTime.now().toUtc();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          workoutRepositoryProvider.overrideWithValue(repository),
        ],
        child: ChocoLogApp(onboardingPreferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('チェストプレス'));
    await tester.pumpAndSettle();
    expect(find.text('前回の3セットをコピー'), findsOneWidget);
    expect(find.text('10 回'), findsOneWidget);
    expect(find.text('15 回'), findsOneWidget);
    expect(find.text('20 回'), findsOneWidget);
    expect(find.text('25 回'), findsOneWidget);
    expect(find.text('12 回'), findsNothing);
    await tester.tap(find.text('このセットを追加'));
    await tester.pumpAndSettle();
    expect(await repository.getActiveSession(), isNull);
    expect(await repository.getCompletedSessionSummaries(), hasLength(2));
    await tester.tap(find.text('前回の3セットをコピー'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('今回のセット'), findsOneWidget);
    expect(find.text('20kg × 15回'), findsWidgets);
    expect(await database.select(database.exerciseSets).get(), hasLength(7));

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('このセットを追加'));
    await tester.pumpAndSettle();
    final todaySession = await repository.getTodaySession();
    final currentSets = await repository.getSessionSets(
      sessionId: todaySession!.id,
      equipmentId: 'chest-press',
    );
    expect(currentSets.last.weightKg, isNull);
    expect(await database.select(database.exerciseSets).get(), hasLength(8));

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5セット目の操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '30');
    await tester.enterText(find.byType(TextFormField).last, '10');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final editedSets = await repository.getSessionSets(
      sessionId: todaySession.id,
      equipmentId: 'chest-press',
    );
    expect(editedSets.last.weightKg, 30);
    expect(editedSets.last.reps, 10);

    expect(await repository.getActiveSession(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('アブベンチ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アブベンチ'));
    await tester.pumpAndSettle();

    expect(find.text('自重トレーニング'), findsOneWidget);
    expect(find.text('重量'), findsNothing);
    await tester.tap(find.text('同じ内容を3セット追加'));
    await tester.pumpAndSettle();

    expect(find.text('自重 × 15回'), findsNWidgets(3));
    expect(await database.select(database.exerciseSets).get(), hasLength(11));

    expect(await repository.getActiveSession(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.textContaining('チェストプレス'), findsWidgets);
    expect(find.textContaining('アブベンチ'), findsWidgets);
    expect(find.text('今日 5セット・合計70回'), findsOneWidget);
    expect(find.text('今日 15回 × 3セット'), findsOneWidget);
    expect(find.text('今日の記録を完了'), findsNothing);
    expect(await repository.getActiveSession(), isNull);
    final homeHistory = await repository.getCompletedSessionSummaries();
    expect(
      homeHistory.first.exercises.map((exercise) => exercise.equipmentName),
      ['チェストプレス', 'アブベンチ'],
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.textContaining('チェストプレス'), findsWidgets);

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final completedSessionTitle = find.textContaining('2種目・8セット');
    expect(find.text('チェストプレス・アブベンチ'), findsOneWidget);
    expect(completedSessionTitle, findsOneWidget);
    await tester.tap(
      find.ancestor(of: completedSessionTitle, matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();

    expect(find.text('トレーニング詳細'), findsOneWidget);
    final detailDate = current.toLocal();
    expect(
      find.text('${detailDate.year}年${detailDate.month}月${detailDate.day}日'),
      findsOneWidget,
    );
    expect(find.text('チェストプレス'), findsOneWidget);
    expect(find.text('アブベンチ'), findsOneWidget);
    expect(find.textContaining('30kg × 10回'), findsOneWidget);
    expect(find.textContaining('自重 × 15回'), findsNWidgets(3));

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この記録を削除'));
    await tester.pumpAndSettle();
    expect(find.text('記録を削除しますか？'), findsOneWidget);
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();

    expect(find.text('トレーニング詳細'), findsNothing);
    expect(await repository.getCompletedSessionSummaries(), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('有酸素タイマーを一時停止して完了できる', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await EquipmentRepository(database).seedDefaults();
    var current = DateTime.now().toUtc();
    var id = 0;
    final repository = WorkoutRepository(
      database,
      idGenerator: () => 'timer-${id++}',
      now: () => current,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          workoutRepositoryProvider.overrideWithValue(repository),
        ],
        child: ChocoLogApp(onboardingPreferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('トレッドミル'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('トレッドミル'));
    await tester.pumpAndSettle();

    expect(find.text('開始前'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1.2');
    await tester.tap(find.text('タイマーを開始'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('計測中'), findsOneWidget);

    current = current.add(const Duration(seconds: 90));
    await tester.tap(find.text('一時停止'));
    await tester.pumpAndSettle();
    expect(find.text('一時停止中'), findsOneWidget);

    current = current.add(const Duration(seconds: 30));
    await tester.tap(find.text('再開'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    current = current.add(const Duration(seconds: 30));
    await tester.tap(find.text('この器具を終了'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.text('今日の記録'), findsOneWidget);
    expect(find.text('トレッドミル'), findsWidgets);
    expect(find.textContaining('2分・1.2km'), findsOneWidget);
    expect(find.text('今日 2分'), findsOneWidget);
    expect(find.text('今日の記録を完了'), findsNothing);
    expect(await repository.getActiveSession(), isNull);
    expect(await repository.getCompletedSessionSummaries(), hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('有酸素運動を時間指定で手動保存できる', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});
    final preferences = await OnboardingPreferences.load();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await EquipmentRepository(database).seedDefaults();
    final repository = WorkoutRepository(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          workoutRepositoryProvider.overrideWithValue(repository),
        ],
        child: ChocoLogApp(onboardingPreferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('バイク'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('バイク'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手動で記録'));
    await tester.pumpAndSettle();

    for (final label in ['10分', '20分', '30分', '45分']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('30分'));
    await tester.tap(find.text('この内容で記録'));
    await tester.pumpAndSettle();

    final sessions = await repository.getCompletedSessionSummaries();
    expect(sessions, hasLength(1));
    expect(sessions.single.exercises.single.equipmentName, 'バイク');
    expect(sessions.single.exercises.single.durationSeconds, 30 * 60);
    expect(await repository.getActiveSession(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
