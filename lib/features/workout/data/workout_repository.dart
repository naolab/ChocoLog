import 'dart:math';

import 'package:chocolog/core/database/app_database.dart';
import 'package:drift/drift.dart';

typedef IdGenerator = String Function();
typedef Now = DateTime Function();

class ExerciseSetValue {
  const ExerciseSetValue({
    required this.weightKg,
    required this.reps,
    this.id,
    this.setNumber,
  });

  final int? weightKg;
  final int reps;
  final String? id;
  final int? setNumber;
}

class WorkoutSessionSnapshot {
  const WorkoutSessionSnapshot({
    required this.id,
    required this.studioId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.note,
  });

  final String id;
  final String? studioId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? note;
}

class WorkoutExerciseSummary {
  const WorkoutExerciseSummary({
    required this.recordId,
    required this.equipmentId,
    required this.equipmentName,
    required this.recordType,
    required this.sets,
    required this.durationSeconds,
    required this.distanceKm,
    required this.timerStatus,
  });

  final String recordId;
  final String equipmentId;
  final String equipmentName;
  final String recordType;
  final List<ExerciseSetValue> sets;
  final int? durationSeconds;
  final double? distanceKm;
  final String timerStatus;
}

class WorkoutSessionSummary {
  const WorkoutSessionSummary({required this.session, required this.exercises});

  final WorkoutSessionSnapshot session;
  final List<WorkoutExerciseSummary> exercises;

  int get totalSetCount =>
      exercises.fold(0, (total, exercise) => total + exercise.sets.length);

  int get totalCardioSeconds => exercises.fold(
    0,
    (total, exercise) => total + (exercise.durationSeconds ?? 0),
  );
}

class CardioRecordSnapshot {
  const CardioRecordSnapshot({
    required this.id,
    required this.sessionId,
    required this.equipmentId,
    required this.startedAt,
    required this.pausedAt,
    required this.endedAt,
    required this.accumulatedPausedSeconds,
    required this.timerStatus,
    required this.durationSeconds,
    required this.distanceKm,
  });

  final String id;
  final String sessionId;
  final String equipmentId;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int accumulatedPausedSeconds;
  final String timerStatus;
  final int? durationSeconds;
  final double? distanceKm;

  int elapsedSecondsAt(DateTime now) {
    if (durationSeconds != null) return durationSeconds!;
    if (startedAt == null) return 0;
    final anchor = timerStatus == 'paused' ? pausedAt ?? now : now;
    return max(
      0,
      anchor.difference(startedAt!).inSeconds - accumulatedPausedSeconds,
    );
  }
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
    return rows.map(_setFromRow).toList(growable: false);
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
    return rows.map(_setFromRow).toList(growable: false);
  }

  Future<CardioRecordSnapshot?> getCardioRecord({
    required String sessionId,
    required String equipmentId,
  }) async {
    final query = _database.select(_database.exerciseRecords)
      ..where(
        (row) =>
            row.workoutSessionId.equals(sessionId) &
            row.equipmentId.equals(equipmentId) &
            row.recordType.equals('cardio'),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _cardioFromRow(row);
  }

  Future<CardioRecordSnapshot> startCardio({
    required String sessionId,
    required String equipmentId,
  }) async {
    final existing = await getCardioRecord(
      sessionId: sessionId,
      equipmentId: equipmentId,
    );
    if (existing != null) return existing;
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
      if (equipment == null || equipment.metricType != 'cardio') {
        throw ArgumentError.value(equipmentId, 'equipmentId', '有酸素器具ではありません');
      }
      final latestRecord =
          await (_database.select(_database.exerciseRecords)
                ..where((row) => row.workoutSessionId.equals(sessionId))
                ..orderBy([(row) => OrderingTerm.desc(row.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      final now = _now();
      final row = ExerciseRecordsCompanion.insert(
        id: _idGenerator(),
        workoutSessionId: sessionId,
        equipmentId: equipmentId,
        recordType: 'cardio',
        startedAt: Value(now),
        timerStatus: const Value('running'),
        sortOrder: Value((latestRecord?.sortOrder ?? -1) + 1),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      await _database.into(_database.exerciseRecords).insert(row);
      return (await getCardioRecord(
        sessionId: sessionId,
        equipmentId: equipmentId,
      ))!;
    });
  }

  Future<CardioRecordSnapshot> pauseCardio(String recordId) async {
    final row = await _activeCardioRow(recordId);
    if (row.timerStatus != 'running') return _cardioFromRow(row);
    final now = _now();
    await (_database.update(
      _database.exerciseRecords,
    )..where((item) => item.id.equals(recordId))).write(
      ExerciseRecordsCompanion(
        pausedAt: Value(now),
        timerStatus: const Value('paused'),
        updatedAt: Value(now),
      ),
    );
    return _cardioFromRow(
      await (_database.select(
        _database.exerciseRecords,
      )..where((item) => item.id.equals(recordId))).getSingle(),
    );
  }

  Future<CardioRecordSnapshot> resumeCardio(String recordId) async {
    final row = await _activeCardioRow(recordId);
    if (row.timerStatus != 'paused' || row.pausedAt == null) {
      return _cardioFromRow(row);
    }
    final now = _now();
    final pausedSeconds = now.difference(row.pausedAt!).inSeconds;
    await (_database.update(
      _database.exerciseRecords,
    )..where((item) => item.id.equals(recordId))).write(
      ExerciseRecordsCompanion(
        pausedAt: const Value(null),
        accumulatedPausedSeconds: Value(
          row.accumulatedPausedSeconds + max(0, pausedSeconds),
        ),
        timerStatus: const Value('running'),
        updatedAt: Value(now),
      ),
    );
    return _cardioFromRow(
      await (_database.select(
        _database.exerciseRecords,
      )..where((item) => item.id.equals(recordId))).getSingle(),
    );
  }

  Future<CardioRecordSnapshot> finishCardio({
    required String recordId,
    double? distanceKm,
  }) async {
    if (distanceKm != null && distanceKm < 0) {
      throw ArgumentError.value(distanceKm, 'distanceKm', '0以上で入力してください');
    }
    final row = await _activeCardioRow(recordId);
    final now = _now();
    final snapshot = _cardioFromRow(row);
    final durationSeconds = snapshot.elapsedSecondsAt(now);
    if (durationSeconds <= 0) throw StateError('1秒以上計測してください');
    await (_database.update(
      _database.exerciseRecords,
    )..where((item) => item.id.equals(recordId))).write(
      ExerciseRecordsCompanion(
        endedAt: Value(now),
        pausedAt: const Value(null),
        timerStatus: const Value('completed'),
        durationSeconds: Value(durationSeconds),
        distanceKm: Value(distanceKm),
        updatedAt: Value(now),
      ),
    );
    return _cardioFromRow(
      await (_database.select(
        _database.exerciseRecords,
      )..where((item) => item.id.equals(recordId))).getSingle(),
    );
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
          recordId: record.id,
          equipmentId: equipment.id,
          equipmentName: equipment.name,
          recordType: record.recordType,
          sets: setRows.map(_setFromRow).toList(growable: false),
          durationSeconds: record.durationSeconds,
          distanceKm: record.distanceKm,
          timerStatus: record.timerStatus,
        ),
      );
    }
    return WorkoutSessionSummary(
      session: _sessionFromRow(session),
      exercises: exercises,
    );
  }

  Future<List<WorkoutSessionSummary>> getCompletedSessionSummaries() async {
    final sessions =
        await (_database.select(_database.workoutSessions)
              ..where((row) => row.status.equals('completed'))
              ..orderBy([
                (row) => OrderingTerm.desc(row.startedAt),
                (row) => OrderingTerm.desc(row.endedAt),
              ]))
            .get();
    return Future.wait([
      for (final session in sessions) getSessionSummary(session.id),
    ]);
  }

  Future<WorkoutSessionSnapshot> duplicateCompletedSession(
    String sourceSessionId,
  ) async {
    final source = await getSessionSummary(sourceSessionId);
    if (source.session.status != 'completed') {
      throw StateError('完了済みの記録だけ複製できます');
    }
    final duplicated = await startSession(studioId: source.session.studioId);
    try {
      var copiedExerciseCount = 0;
      for (final exercise in source.exercises) {
        if (exercise.sets.isEmpty) continue;
        await addExerciseSets(
          sessionId: duplicated.id,
          equipmentId: exercise.equipmentId,
          sets: exercise.sets,
        );
        copiedExerciseCount++;
      }
      if (copiedExerciseCount == 0) {
        throw StateError('複製できるセット記録がありません');
      }
      return duplicated;
    } catch (_) {
      await (_database.delete(
        _database.workoutSessions,
      )..where((row) => row.id.equals(duplicated.id))).go();
      rethrow;
    }
  }

  Future<void> deleteCompletedSession(String sessionId) async {
    final session = await (_database.select(
      _database.workoutSessions,
    )..where((row) => row.id.equals(sessionId))).getSingleOrNull();
    if (session == null || session.status != 'completed') {
      throw StateError('削除できる完了済み記録が見つかりません');
    }
    await (_database.delete(
      _database.workoutSessions,
    )..where((row) => row.id.equals(sessionId))).go();
  }

  Future<void> updateExerciseSet({
    required String setId,
    required int? weightKg,
    required int reps,
  }) async {
    if (reps <= 0) throw ArgumentError.value(reps, 'reps', '1回以上必要です');
    if (weightKg != null && (weightKg < 0 || weightKg % 5 != 0)) {
      throw ArgumentError.value(weightKg, 'weightKg', '5kg単位で入力してください');
    }
    final result = await _editableSet(setId);
    final record = result.readTable(_database.exerciseRecords);
    if (record.recordType == 'bodyweight' && weightKg != null) {
      throw ArgumentError.value(weightKg, 'weightKg', '自重種目に重量は設定できません');
    }
    final timestamp = _now();
    await (_database.update(
      _database.exerciseSets,
    )..where((row) => row.id.equals(setId))).write(
      ExerciseSetsCompanion(
        weightKg: Value(weightKg),
        reps: Value(reps),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> deleteExerciseSet(String setId) async {
    await _database.transaction(() async {
      final result = await _editableSet(setId);
      final set = result.readTable(_database.exerciseSets);
      await (_database.delete(
        _database.exerciseSets,
      )..where((row) => row.id.equals(setId))).go();
      final remainingQuery = _database.select(_database.exerciseSets)
        ..where((row) => row.exerciseRecordId.equals(set.exerciseRecordId))
        ..orderBy([(row) => OrderingTerm.asc(row.setNumber)]);
      final remaining = await remainingQuery.get();
      if (remaining.isEmpty) {
        await (_database.delete(
          _database.exerciseRecords,
        )..where((row) => row.id.equals(set.exerciseRecordId))).go();
        return;
      }
      for (final (index, row) in remaining.indexed) {
        final nextNumber = index + 1;
        if (row.setNumber == nextNumber) continue;
        await (_database.update(_database.exerciseSets)
              ..where((item) => item.id.equals(row.id)))
            .write(ExerciseSetsCompanion(setNumber: Value(nextNumber)));
      }
    });
  }

  Future<void> updateSessionNote(String sessionId, String? note) async {
    final normalized = note?.trim();
    final updated =
        await (_database.update(
          _database.workoutSessions,
        )..where((row) => row.id.equals(sessionId))).write(
          WorkoutSessionsCompanion(
            note: Value(
              normalized == null || normalized.isEmpty ? null : normalized,
            ),
            updatedAt: Value(_now()),
          ),
        );
    if (updated == 0) throw StateError('セッションが見つかりません');
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
      final unfinishedCardioCount =
          await (_database.select(_database.exerciseRecords)..where(
                (row) =>
                    row.workoutSessionId.equals(sessionId) &
                    row.recordType.equals('cardio') &
                    row.timerStatus.isNotValue('completed'),
              ))
              .get()
              .then((rows) => rows.length);
      if (unfinishedCardioCount > 0) {
        throw StateError('計測中の有酸素タイマーがあります');
      }

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
      note: row.note,
    );
  }

  Future<TypedResult> _editableSet(String setId) async {
    final query =
        _database.select(_database.exerciseSets).join([
          innerJoin(
            _database.exerciseRecords,
            _database.exerciseRecords.id.equalsExp(
              _database.exerciseSets.exerciseRecordId,
            ),
          ),
          innerJoin(
            _database.workoutSessions,
            _database.workoutSessions.id.equalsExp(
              _database.exerciseRecords.workoutSessionId,
            ),
          ),
        ])..where(
          _database.exerciseSets.id.equals(setId) &
              _database.workoutSessions.status.equals('draft'),
        );
    final result = await query.getSingleOrNull();
    if (result == null) throw StateError('編集中のセットが見つかりません');
    return result;
  }

  static ExerciseSetValue _setFromRow(ExerciseSetRow row) => ExerciseSetValue(
    id: row.id,
    setNumber: row.setNumber,
    weightKg: row.weightKg,
    reps: row.reps,
  );

  Future<ExerciseRecordRow> _activeCardioRow(String recordId) async {
    final query =
        _database.select(_database.exerciseRecords).join([
          innerJoin(
            _database.workoutSessions,
            _database.workoutSessions.id.equalsExp(
              _database.exerciseRecords.workoutSessionId,
            ),
          ),
        ])..where(
          _database.exerciseRecords.id.equals(recordId) &
              _database.exerciseRecords.recordType.equals('cardio') &
              _database.workoutSessions.status.equals('draft'),
        );
    final result = await query.getSingleOrNull();
    if (result == null) throw StateError('計測中の有酸素記録が見つかりません');
    return result.readTable(_database.exerciseRecords);
  }

  static CardioRecordSnapshot _cardioFromRow(ExerciseRecordRow row) =>
      CardioRecordSnapshot(
        id: row.id,
        sessionId: row.workoutSessionId,
        equipmentId: row.equipmentId,
        startedAt: row.startedAt,
        pausedAt: row.pausedAt,
        endedAt: row.endedAt,
        accumulatedPausedSeconds: row.accumulatedPausedSeconds,
        timerStatus: row.timerStatus,
        durationSeconds: row.durationSeconds,
        distanceKm: row.distanceKm,
      );
}
