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
    expect(await database.select(database.exerciseRecords).get(), hasLength(1));
    expect(previous.map((set) => set.weightKg), [20, 20, 25]);
    expect(previous.map((set) => set.reps), [15, 15, 12]);
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
}
