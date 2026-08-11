import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late EquipmentRepository equipmentRepository;
  late WorkoutRepository workoutRepository;
  late int idSequence;
  late int minuteSequence;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    equipmentRepository = EquipmentRepository(database);
    idSequence = 0;
    minuteSequence = 0;
    workoutRepository = WorkoutRepository(
      database,
      idGenerator: () => 'id-${idSequence++}',
      now: () => DateTime.utc(2026, 8, 11, 10, minuteSequence++),
    );
    await equipmentRepository.seedDefaults();
  });

  tearDown(() => database.close());

  test('初期器具マスタを重複なく投入できる', () async {
    await equipmentRepository.seedDefaults();

    final equipment = await equipmentRepository.watchActive().first;

    expect(equipment, hasLength(12));
    expect(equipment.first.name, 'ショルダープレス');
    expect(equipment.last.metricType, 'cardio');
  });

  test('セッションを開始して筋トレ3セットを完了できる', () async {
    final session = await workoutRepository.startSession();

    await workoutRepository.addExerciseSets(
      sessionId: session.id,
      equipmentId: 'chest-press',
      sets: const [ExerciseSetValue(weightKg: 20, reps: 15)],
    );
    await workoutRepository.addExerciseSets(
      sessionId: session.id,
      equipmentId: 'chest-press',
      sets: const [
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 25, reps: 12),
      ],
    );
    await workoutRepository.completeSession(session.id);

    expect(await workoutRepository.getActiveSession(), isNull);
    final previous = await workoutRepository.getPreviousSets('chest-press');
    final summary = await workoutRepository.getSessionSummary(session.id);
    expect(await database.select(database.exerciseRecords).get(), hasLength(1));
    expect(previous.map((set) => set.weightKg), [20, 20, 25]);
    expect(previous.map((set) => set.reps), [15, 15, 12]);
    expect(summary.exercises.single.equipmentName, 'チェストプレス');
    expect(summary.totalSetCount, 3);
  });

  test('進行中セッションを複数作成できない', () async {
    final session = await workoutRepository.startSession(studioId: 'studio-1');

    await expectLater(
      workoutRepository.startSession(),
      throwsA(isA<StateError>()),
    );
    final active = await workoutRepository.getActiveSession();
    expect(active?.id, session.id);
    expect(active?.studioId, 'studio-1');
  });

  test('セット保存に失敗した場合は種目記録もロールバックされる', () async {
    final session = await workoutRepository.startSession();

    await expectLater(
      workoutRepository.addExerciseSets(
        sessionId: session.id,
        equipmentId: 'leg-press',
        sets: const [ExerciseSetValue(weightKg: 22, reps: 15)],
      ),
      throwsA(isA<Exception>()),
    );

    expect(await database.select(database.exerciseRecords).get(), isEmpty);
    expect(await database.select(database.exerciseSets).get(), isEmpty);
  });

  test('記録がないセッションは完了できない', () async {
    final session = await workoutRepository.startSession();

    await expectLater(
      workoutRepository.completeSession(session.id),
      throwsA(isA<StateError>()),
    );
    expect((await workoutRepository.getActiveSession())?.id, session.id);
  });

  test('自重種目は重量なしで保存できる', () async {
    final session = await workoutRepository.startSession();

    await workoutRepository.addExerciseSets(
      sessionId: session.id,
      equipmentId: 'ab-bench',
      sets: const [ExerciseSetValue(weightKg: null, reps: 15)],
    );

    final set = await database.select(database.exerciseSets).getSingle();
    expect(set.weightKg, isNull);
    expect(set.reps, 15);
  });

  test('完了済みセッションを新しい順で取得できる', () async {
    final firstSession = await workoutRepository.startSession();
    await workoutRepository.addExerciseSets(
      sessionId: firstSession.id,
      equipmentId: 'chest-press',
      sets: const [ExerciseSetValue(weightKg: 20, reps: 15)],
    );
    await workoutRepository.completeSession(firstSession.id);

    final secondSession = await workoutRepository.startSession();
    await workoutRepository.addExerciseSets(
      sessionId: secondSession.id,
      equipmentId: 'ab-bench',
      sets: const [
        ExerciseSetValue(weightKg: null, reps: 15),
        ExerciseSetValue(weightKg: null, reps: 15),
      ],
    );
    await workoutRepository.completeSession(secondSession.id);

    final history = await workoutRepository.getCompletedSessionSummaries();

    expect(history.map((summary) => summary.session.id), [
      secondSession.id,
      firstSession.id,
    ]);
    expect(history.first.exercises.single.equipmentName, 'アブベンチ');
    expect(history.first.totalSetCount, 2);
  });

  test('完了済みメニューを複製し、過去の記録を削除できる', () async {
    final source = await workoutRepository.startSession();
    await workoutRepository.addExerciseSets(
      sessionId: source.id,
      equipmentId: 'chest-press',
      sets: const [
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 25, reps: 12),
      ],
    );
    await workoutRepository.completeSession(source.id);

    final duplicated = await workoutRepository.duplicateCompletedSession(
      source.id,
    );
    final duplicatedSummary = await workoutRepository.getSessionSummary(
      duplicated.id,
    );

    expect(duplicatedSummary.session.status, 'draft');
    expect(duplicatedSummary.exercises.single.sets.map((set) => set.weightKg), [
      20,
      25,
    ]);
    expect(duplicatedSummary.exercises.single.sets.map((set) => set.reps), [
      15,
      12,
    ]);

    await workoutRepository.deleteCompletedSession(source.id);

    expect(await workoutRepository.getCompletedSessionSummaries(), isEmpty);
    expect((await workoutRepository.getActiveSession())?.id, duplicated.id);
  });

  test('進行中のセットを編集・削除して番号を詰め直せる', () async {
    final session = await workoutRepository.startSession();
    await workoutRepository.addExerciseSets(
      sessionId: session.id,
      equipmentId: 'chest-press',
      sets: const [
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 20, reps: 15),
        ExerciseSetValue(weightKg: 20, reps: 15),
      ],
    );
    final original = await workoutRepository.getSessionSets(
      sessionId: session.id,
      equipmentId: 'chest-press',
    );

    await workoutRepository.updateExerciseSet(
      setId: original[1].id!,
      weightKg: 25,
      reps: 12,
    );
    await workoutRepository.deleteExerciseSet(original.first.id!);
    await workoutRepository.updateSessionNote(session.id, 'フォームを意識した');

    final updated = await workoutRepository.getSessionSets(
      sessionId: session.id,
      equipmentId: 'chest-press',
    );
    final summary = await workoutRepository.getSessionSummary(session.id);
    expect(updated.map((set) => set.setNumber), [1, 2]);
    expect(updated.first.weightKg, 25);
    expect(updated.first.reps, 12);
    expect(summary.session.note, 'フォームを意識した');
  });

  test('有酸素タイマーをバックグラウンド時間込みで復元できる', () async {
    var current = DateTime.utc(2026, 8, 11, 10);
    var cardioId = 0;
    final repository = WorkoutRepository(
      database,
      idGenerator: () => 'cardio-${cardioId++}',
      now: () => current,
    );
    final session = await repository.startSession();
    final started = await repository.startCardio(
      sessionId: session.id,
      equipmentId: 'treadmill',
    );

    current = DateTime.utc(2026, 8, 11, 10, 5);
    final restored = await repository.getCardioRecord(
      sessionId: session.id,
      equipmentId: 'treadmill',
    );
    expect(restored?.elapsedSecondsAt(current), 300);
    await expectLater(
      repository.completeSession(session.id),
      throwsA(isA<StateError>()),
    );

    await repository.pauseCardio(started.id);
    current = DateTime.utc(2026, 8, 11, 10, 7);
    await repository.resumeCardio(started.id);
    current = DateTime.utc(2026, 8, 11, 10, 10);
    final completed = await repository.finishCardio(
      recordId: started.id,
      distanceKm: 1.5,
    );
    await repository.completeSession(session.id);

    final summary = await repository.getSessionSummary(session.id);
    expect(completed.durationSeconds, 480);
    expect(completed.distanceKm, 1.5);
    expect(summary.totalCardioSeconds, 480);
    expect(summary.exercises.single.equipmentName, 'トレッドミル');
    expect(summary.exercises.single.timerStatus, 'completed');
  });
}
