import 'package:chocolog/app/app.dart';
import 'package:chocolog/app/theme.dart';
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

    expect(find.byKey(const Key('home-wordmark')), findsOneWidget);
    expect(find.text('店舗未設定'), findsOneWidget);
    expect(find.text('器具を選んで記録'), findsOneWidget);
    expect(find.text('ショルダープレス'), findsOneWidget);
    expect(preferences.isCompleted, isTrue);
    expect(preferences.weeklyTarget, 3);
    expect(preferences.reminderEnabled, isTrue);
    expect(preferences.reminderWeekdays, [DateTime.tuesday, DateTime.saturday]);
    expect(preferences.reminderHour, 19);
    expect(preferences.reminderMinute, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
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

    expect(find.text('器具を選んで記録'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('チェストプレス'));
    await tester.pumpAndSettle();
    expect(find.text('前回のセット'), findsNothing);
    await tester.drag(
      find.byKey(const Key('strength-entry-list')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    expect(find.text('10 kg'), findsWidgets);
    expect(find.text('20 kg'), findsWidgets);
    expect(find.text('このセットを追加'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(find.text('トレーニングの記録がここに表示されます'), findsOneWidget);
    await tester.tap(find.text('分析'));
    await tester.pumpAndSettle();
    expect(find.text('この期間の記録はありません'), findsOneWidget);

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    expect(find.text('週の目標回数'), findsOneWidget);
    expect(find.text('週間リマインダー'), findsOneWidget);
    expect(find.text('重量単位'), findsNothing);
    expect(find.text('週の開始曜日'), findsNothing);
    expect(find.text('未設定'), findsOneWidget);

    await tester.tap(find.text('週2回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('週3回').last);
    await tester.pumpAndSettle();
    expect(preferences.weeklyTarget, 3);

    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(find.text('器具を選んで記録'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('通知時刻を日本語の3項目で表示できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'onboarding.completed': true,
      'reminder.enabled': true,
      'reminder.hour': 19,
      'reminder.minute': 0,
    });
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
    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();

    expect(find.text('通知時刻'), findsOneWidget);
    expect(find.text('午前・午後'), findsOneWidget);
    expect(find.text('午後'), findsOneWidget);
    expect(find.text('時'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
    expect(find.textContaining('午後 7:00'), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('重量単位'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('保存方法について'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('保存方法について'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, isNull);
    expect(
      Theme.of(
        tester.element(find.byType(AlertDialog)),
      ).dialogTheme.backgroundColor,
      const Color(0xFFFFFFFF),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
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

    await tester.drag(find.byType(ListView).last, const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.textContaining('チェストプレス'), findsWidgets);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分析'));
    await tester.pumpAndSettle();
    expect(find.text('概要'), findsOneWidget);
    expect(find.text('トレーニング'), findsOneWidget);
    expect(find.text('1日'), findsWidgets);
    expect(find.text('2セット'), findsOneWidget);
    expect(find.text('目標まであと1回'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.text('週目標を達成した週 0週'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('日ごとの運動量'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('器具ごとのセット数を日別に表示'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('analysis-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('筋トレ'), findsWidgets);
    expect(find.text('有酸素'), findsWidgets);
    expect(find.text('器具ごとのセット数を日別に表示'), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-legend-チェストプレス')), findsOneWidget);
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final todayKey = ValueKey(
      'analysis-day-${DateTime(today.year, today.month, today.day).toIso8601String()}',
    );
    expect(
      find.byKey(ValueKey('analysis-day-${tomorrow.toIso8601String()}')),
      findsNothing,
    );
    await tester.ensureVisible(find.byKey(todayKey));
    await tester.pumpAndSettle();
    final bar = tester.widget<Container>(
      find.byKey(
        ValueKey(
          'analysis-bar-${DateTime(today.year, today.month, today.day).toIso8601String()}-2',
        ),
      ),
    );
    expect(bar.child, isA<SizedBox>());
    final decoration = bar.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(7));
    expect(find.text('2セット'), findsWidgets);
    await tester.tap(find.byKey(todayKey));
    await tester.pumpAndSettle();
    final selectedDateLabel = tester.widget<AnimatedContainer>(
      find.byKey(
        ValueKey(
          'analysis-date-label-${DateTime(today.year, today.month, today.day).toIso8601String()}',
        ),
      ),
    );
    expect(
      (selectedDateLabel.decoration! as BoxDecoration).color,
      ChocoLogColors.softYellow,
    );
    expect(find.text('${today.month}月${today.day}日の記録'), findsOneWidget);
    expect(find.text('チェストプレス'), findsWidgets);
    expect(find.text('2セット'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('よく使った器具'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('analysis-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('よく使った器具'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('analysis-list')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(find.text('合計 2セット・最大 25kg'), findsOneWidget);
    expect(find.text('2セット'), findsWidgets);
    expect(find.text('筋トレ（セット数順）'), findsOneWidget);
    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    final sessionTitle = find.textContaining('1種目・2セット');
    final sessionCard = find.ancestor(
      of: sessionTitle,
      matching: find.byType(Card),
    );
    final sessionCardText = tester.widgetList<Text>(
      find.descendant(of: sessionCard, matching: find.byType(Text)),
    );
    expect(
      sessionCardText.any(
        (text) => RegExp(r'\d{1,2}:\d{2}').hasMatch(text.data ?? ''),
      ),
      isFalse,
    );
    await tester.pumpAndSettle();
    final historySession = find.descendant(
      of: sessionCard,
      matching: find.byKey(ValueKey('history-session-${previous.id}')),
    );
    await tester.ensureVisible(historySession);
    await tester.tap(historySession);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('このメニューを複製'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('このメニューを複製'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-wordmark')), findsOneWidget);
    expect(find.textContaining('チェストプレス'), findsWidgets);
    final active = await repository.getActiveSession();
    expect(active, isNull);
    expect(await repository.getCompletedSessionSummaries(), hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
