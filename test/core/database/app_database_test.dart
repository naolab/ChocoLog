import 'package:chocolog/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('筋力トレーニングのセットを保存できる', () async {
    final now = DateTime.utc(2026, 8, 11, 10);

    await database
        .into(database.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'chest-press',
            name: 'チェストプレス',
            category: 'upperBody',
            metricType: 'strength',
          ),
        );
    await database
        .into(database.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(id: 'session-1', startedAt: now),
        );
    await database
        .into(database.exerciseRecords)
        .insert(
          ExerciseRecordsCompanion.insert(
            id: 'record-1',
            workoutSessionId: 'session-1',
            equipmentId: 'chest-press',
            recordType: 'strength',
          ),
        );
    await database.batch((batch) {
      batch.insertAll(database.exerciseSets, [
        ExerciseSetsCompanion.insert(
          id: 'set-1',
          exerciseRecordId: 'record-1',
          setNumber: 1,
          weightKg: const Value(20),
          reps: 15,
        ),
        ExerciseSetsCompanion.insert(
          id: 'set-2',
          exerciseRecordId: 'record-1',
          setNumber: 2,
          weightKg: const Value(20),
          reps: 15,
        ),
        ExerciseSetsCompanion.insert(
          id: 'set-3',
          exerciseRecordId: 'record-1',
          setNumber: 3,
          weightKg: const Value(20),
          reps: 15,
        ),
      ]);
    });

    final sets = await database.select(database.exerciseSets).get();

    expect(sets, hasLength(3));
    expect(sets.first.weightKg, 20);
    expect(sets.first.reps, 15);
  });

  test('セッションを削除すると記録とセットも削除される', () async {
    final now = DateTime.utc(2026, 8, 11, 10);

    await database
        .into(database.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'ab-bench',
            name: 'アブベンチ',
            category: 'core',
            metricType: 'bodyweight',
          ),
        );
    await database
        .into(database.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(id: 'session-1', startedAt: now),
        );
    await database
        .into(database.exerciseRecords)
        .insert(
          ExerciseRecordsCompanion.insert(
            id: 'record-1',
            workoutSessionId: 'session-1',
            equipmentId: 'ab-bench',
            recordType: 'bodyweight',
          ),
        );
    await database
        .into(database.exerciseSets)
        .insert(
          ExerciseSetsCompanion.insert(
            id: 'set-1',
            exerciseRecordId: 'record-1',
            setNumber: 1,
            reps: 15,
          ),
        );

    await (database.delete(
      database.workoutSessions,
    )..where((row) => row.id.equals('session-1'))).go();

    expect(await database.select(database.exerciseRecords).get(), isEmpty);
    expect(await database.select(database.exerciseSets).get(), isEmpty);
  });

  test('5kg単位ではない重量を保存できない', () async {
    final now = DateTime.utc(2026, 8, 11, 10);

    await database
        .into(database.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'leg-press',
            name: 'レッグプレス',
            category: 'lowerBody',
            metricType: 'strength',
          ),
        );
    await database
        .into(database.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(id: 'session-1', startedAt: now),
        );
    await database
        .into(database.exerciseRecords)
        .insert(
          ExerciseRecordsCompanion.insert(
            id: 'record-1',
            workoutSessionId: 'session-1',
            equipmentId: 'leg-press',
            recordType: 'strength',
          ),
        );

    await expectLater(
      database
          .into(database.exerciseSets)
          .insert(
            ExerciseSetsCompanion.insert(
              id: 'set-1',
              exerciseRecordId: 'record-1',
              setNumber: 1,
              weightKg: const Value(22),
              reps: 15,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
