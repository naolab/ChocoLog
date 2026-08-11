import 'dart:math';

import 'package:chocolog/core/database/app_database.dart';
import 'package:drift/drift.dart';

typedef IdGenerator = String Function();
typedef Now = DateTime Function();

class ExerciseSetValue {
  const ExerciseSetValue({required this.weightKg, required this.reps});

  final int? weightKg;
  final int reps;
}

class WorkoutSessionSnapshot {
  const WorkoutSessionSnapshot({
    required this.id,
    required this.studioId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  final String id;
  final String? studioId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
}

class WorkoutExerciseSummary {
  const WorkoutExerciseSummary({
    required this.equipmentId,
    required this.equipmentName,
    required this.recordType,
    required this.sets,
  });

  final String equipmentId;
  final String equipmentName;
  final String recordType;
  final List<ExerciseSetValue> sets;
}

class WorkoutSessionSummary {
  const WorkoutSessionSummary({required this.session, required this.exercises});

  final WorkoutSessionSnapshot session;
  final List<WorkoutExerciseSummary> exercises;

  int get totalSetCount =>
      exercises.fold(0, (total, exercise) => total + exercise.sets.length);
}

class WorkoutRepository {
  WorkoutRepository(this._database, {IdGenerator? idGenerator, Now? now})
    : _idGenerator = idGenerator ?? _defaultId,
      _now = now ?? _utcNow;

  final AppDatabase _database;
  final IdGenerator _idGenerator;
  final Now _now;

  static final _random = Random.secure();

  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<WorkoutSessionSnapshot> startSession({String? studioId}) async {
    return _database.transaction(() async {
      if (await getActiveSession() != null) {
        throw StateError('進行中のセッションがすでに存在します');
      }
      final startedAt = _now();
      final row = WorkoutSessionRow(
        id: _idGenerator(),
        studioId: studioId,
        status: 'draft',
        startedAt: startedAt,
        endedAt: null,
        note: null,
        createdAt: startedAt,
        updatedAt: startedAt,
      );
      await _database.into(_database.workoutSessions).insert(row);
      return _sessionFromRow(row);
    });
  }

  Future<WorkoutSessionSnapshot?> getActiveSession() async {
    final query = _database.select(_database.workoutSessions)
      ..where((row) => row.status.equals('draft'))
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _sessionFromRow(row);
  }

  Future<String> addExerciseSets({
    required String sessionId,
    required String equipmentId,
    required List<ExerciseSetValue> sets,
  }) async {
    if (sets.isEmpty) throw ArgumentError.value(sets, 'sets', '1セット以上必要です');

    return _database.transaction(() async {
      final session = await (_database.select(
        _database.workoutSessions,
      )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
      if (session == null || session.status != 'draft') {
        throw StateError('進行中のセッションが見つかりません');
      }

      final equipment = await (_database.select(
        _database.equipment,
      )..where((row) => row.id.equals(equipmentId))).getSingleOrNull();
      if (equipment == null ||
          !const {'strength', 'bodyweight'}.contains(equipment.metricType)) {
        throw ArgumentError.value(
          equipmentId,
          'equipmentId',
          'セット記録対象の器具ではありません',
        );
      }
      if (equipment.metricType == 'bodyweight' &&
          sets.any((set) => set.weightKg != null)) {
        throw ArgumentError.value(sets, 'sets', '自重種目に重量は設定できません');
      }

      final existingRecord =
          await (_database.select(_database.exerciseRecords)
                ..where(
                  (row) =>
                      row.workoutSessionId.equals(sessionId) &
                      row.equipmentId.equals(equipmentId) &
                      row.recordType.equals(equipment.metricType),
                )
                ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      final recordId = existingRecord?.id ?? _idGenerator();
      final timestamp = _now();
      if (existingRecord == null) {
        final latestRecord =
            await (_database.select(_database.exerciseRecords)
                  ..where((row) => row.workoutSessionId.equals(sessionId))
                  ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
                  ..limit(1))
                .getSingleOrNull();
        await _database
            .into(_database.exerciseRecords)
            .insert(
              ExerciseRecordsCompanion.insert(
                id: recordId,
                workoutSessionId: sessionId,
                equipmentId: equipmentId,
                recordType: equipment.metricType,
                sortOrder: Value((latestRecord?.sortOrder ?? -1) + 1),
                createdAt: Value(timestamp),
                updatedAt: Value(timestamp),
              ),
            );
      }
      final latestSet =
          await (_database.select(_database.exerciseSets)
                ..where((row) => row.exerciseRecordId.equals(recordId))
                ..orderBy([(row) => OrderingTerm.desc(row.setNumber)])
                ..limit(1))
              .getSingleOrNull();
      final firstSetNumber = (latestSet?.setNumber ?? 0) + 1;
      await _database.batch((batch) {
        batch.insertAll(_database.exerciseSets, [
          for (final (index, set) in sets.indexed)
            ExerciseSetsCompanion.insert(
              id: _idGenerator(),
              exerciseRecordId: recordId,
              setNumber: firstSetNumber + index,
              weightKg: Value(set.weightKg),
              reps: set.reps,
              createdAt: Value(timestamp),
              updatedAt: Value(timestamp),
            ),
        ]);
      });
      return recordId;
    });
  }

  Future<List<ExerciseSetValue>> getPreviousSets(String equipmentId) async {
    final query =
        _database.select(_database.exerciseRecords).join([
            innerJoin(
              _database.workoutSessions,
              _database.workoutSessions.id.equalsExp(
                _database.exerciseRecords.workoutSessionId,
              ),
            ),
          ])
          ..where(
            _database.exerciseRecords.equipmentId.equals(equipmentId) &
                _database.workoutSessions.status.equals('completed'),
          )
          ..orderBy([
            OrderingTerm.desc(_database.workoutSessions.endedAt),
            OrderingTerm.desc(_database.exerciseRecords.createdAt),
          ])
          ..limit(1);
    final result = await query.getSingleOrNull();
    if (result == null) return const [];

    final record = result.readTable(_database.exerciseRecords);
    final setsQuery = _database.select(_database.exerciseSets)
      ..where((row) => row.exerciseRecordId.equals(record.id))
      ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]);
    final rows = await setsQuery.get();
    return rows
        .map((row) => ExerciseSetValue(weightKg: row.weightKg, reps: row.reps))
        .toList(growable: false);
  }

  Future<List<ExerciseSetValue>> getSessionSets({
    required String sessionId,
    required String equipmentId,
  }) async {
    final record =
        await (_database.select(_database.exerciseRecords)
              ..where(
                (row) =>
                    row.workoutSessionId.equals(sessionId) &
                    row.equipmentId.equals(equipmentId),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    if (record == null) return const [];

    final query = _database.select(_database.exerciseSets)
      ..where((row) => row.exerciseRecordId.equals(record.id))
      ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]);
    final rows = await query.get();
    return rows
        .map((row) => ExerciseSetValue(weightKg: row.weightKg, reps: row.reps))
        .toList(growable: false);
  }

  Future<WorkoutSessionSummary> getSessionSummary(String sessionId) async {
    final session = await (_database.select(
      _database.workoutSessions,
    )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
    if (session == null) throw StateError('セッションが見つかりません');

    final records =
        await (_database.select(_database.exerciseRecords).join([
                innerJoin(
                  _database.equipment,
                  _database.equipment.id.equalsExp(
                    _database.exerciseRecords.equipmentId,
                  ),
                ),
              ])
              ..where(
                _database.exerciseRecords.workoutSessionId.equals(sessionId),
              )
              ..orderBy([
                OrderingTerm.asc(_database.exerciseRecords.sortOrder),
              ]))
            .get();
    final exercises = <WorkoutExerciseSummary>[];
    for (final result in records) {
      final record = result.readTable(_database.exerciseRecords);
      final equipment = result.readTable(_database.equipment);
      final setsQuery = _database.select(_database.exerciseSets)
        ..where((row) => row.exerciseRecordId.equals(record.id))
        ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]);
      final setRows = await setsQuery.get();
      exercises.add(
        WorkoutExerciseSummary(
          equipmentId: equipment.id,
          equipmentName: equipment.name,
          recordType: record.recordType,
          sets: setRows
              .map(
                (row) =>
                    ExerciseSetValue(weightKg: row.weightKg, reps: row.reps),
              )
              .toList(growable: false),
        ),
      );
    }
    return WorkoutSessionSummary(
      session: _sessionFromRow(session),
      exercises: exercises,
    );
  }

  Future<void> completeSession(String sessionId) async {
    await _database.transaction(() async {
      final session = await (_database.select(
        _database.workoutSessions,
      )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
      if (session == null || session.status != 'draft') {
        throw StateError('進行中のセッションが見つかりません');
      }
      final countExpression = _database.exerciseRecords.id.count();
      final recordCount =
          await (_database.selectOnly(_database.exerciseRecords)
                ..addColumns([countExpression])
                ..where(
                  _database.exerciseRecords.workoutSessionId.equals(sessionId),
                ))
              .map((row) => row.read(countExpression) ?? 0)
              .getSingle();
      if (recordCount == 0) throw StateError('記録がないセッションは完了できません');

      final endedAt = _now();
      await (_database.update(
        _database.workoutSessions,
      )..where((row) => row.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(
          status: const Value('completed'),
          endedAt: Value(endedAt),
          updatedAt: Value(endedAt),
        ),
      );
    });
  }

  static WorkoutSessionSnapshot _sessionFromRow(WorkoutSessionRow row) {
    return WorkoutSessionSnapshot(
      id: row.id,
      studioId: row.studioId,
      status: row.status,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
    );
  }
}
