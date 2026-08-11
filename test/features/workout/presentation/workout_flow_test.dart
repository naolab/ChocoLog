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
    final repository = WorkoutRepository(database);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: ChocoLogApp(onboardingPreferences: preferences),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('トレーニングを始める'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('店舗を選ばずに続ける'));
    await tester.pumpAndSettle();

    expect(find.text('器具を選ぶ'), findsOneWidget);
    await tester.tap(find.text('チェストプレス'));
    await tester.pumpAndSettle();
    expect(find.text('前回の3セットをコピー'), findsOneWidget);
    await tester.tap(find.text('このセットを追加'));
    await tester.pumpAndSettle();
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
    final activeSession = await repository.getActiveSession();
    final currentSets = await repository.getSessionSets(
      sessionId: activeSession!.id,
      equipmentId: 'chest-press',
    );
    expect(currentSets.last.weightKg, isNull);
    expect(await database.select(database.exerciseSets).get(), hasLength(8));

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();
    expect(find.text('今日の記録'), findsOneWidget);
    expect(find.text('チェストプレス'), findsOneWidget);
    await tester.tap(find.text('別の器具を追加'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('アブベンチ'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('アブベンチ'));
    await tester.pumpAndSettle();

    expect(find.text('自重トレーニング'), findsOneWidget);
    expect(find.text('重量'), findsNothing);
    await tester.tap(find.text('同じ内容を3セット追加'));
    await tester.pumpAndSettle();

    expect(find.text('自重 × 15回'), findsNWidgets(3));
    expect(await database.select(database.exerciseSets).get(), hasLength(11));

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();
    expect(find.text('チェストプレス'), findsOneWidget);
    expect(find.text('アブベンチ'), findsOneWidget);
    await tester.tap(find.text('トレーニングを終了'));
    await tester.pumpAndSettle();

    expect(find.text('2種目・8セット'), findsOneWidget);
    await tester.tap(find.text('保存して完了'));
    await tester.pumpAndSettle();

    expect(find.text('トレーニング完了！'), findsOneWidget);
    expect(find.text('2種目・8セット'), findsOneWidget);
    expect(await repository.getActiveSession(), isNull);
    await tester.tap(find.text('ホームへ戻る'));
    await tester.pumpAndSettle();
    expect(find.text('トレーニングを始める'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
