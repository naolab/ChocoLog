import 'package:chocolog/core/database/database_providers.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workoutFlowControllerProvider =
    StateNotifierProvider<
      WorkoutFlowController,
      AsyncValue<WorkoutSessionSnapshot?>
    >((ref) {
      return WorkoutFlowController(ref.watch(workoutRepositoryProvider));
    });

class WorkoutFlowController
    extends StateNotifier<AsyncValue<WorkoutSessionSnapshot?>> {
  WorkoutFlowController(this._repository) : super(const AsyncData(null));

  final WorkoutRepository _repository;

  Future<WorkoutSessionSnapshot> ensureSession({String? studioId}) async {
    state = const AsyncLoading();
    try {
      final session =
          await _repository.getActiveSession() ??
          await _repository.startSession(studioId: studioId);
      state = AsyncData(session);
      return session;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<ExerciseSetValue>> addSets({
    required String equipmentId,
    required List<ExerciseSetValue> sets,
  }) async {
    state = const AsyncLoading();
    try {
      final session =
          await _repository.getActiveSession() ??
          await _repository.startSession();
      await _repository.addExerciseSets(
        sessionId: session.id,
        equipmentId: equipmentId,
        sets: sets,
      );
      final savedSets = await _repository.getSessionSets(
        sessionId: session.id,
        equipmentId: equipmentId,
      );
      state = AsyncData(session);
      return savedSets;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<ExerciseSetValue>> currentSets(String equipmentId) async {
    final session =
        await _repository.getActiveSession() ??
        await _repository.startSession();
    return _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }

  Future<List<ExerciseSetValue>> updateSet({
    required String equipmentId,
    required String setId,
    required int? weightKg,
    required int reps,
  }) async {
    final session = await _requireActiveSession();
    await _repository.updateExerciseSet(
      setId: setId,
      weightKg: weightKg,
      reps: reps,
    );
    state = AsyncData(session);
    return _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }

  Future<List<ExerciseSetValue>> deleteSet({
    required String equipmentId,
    required String setId,
  }) async {
    final session = await _requireActiveSession();
    await _repository.deleteExerciseSet(setId);
    state = AsyncData(session);
    return _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }

  Future<CardioRecordSnapshot?> currentCardio(String equipmentId) async {
    final session = await _requireActiveSession();
    return _repository.getCardioRecord(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }

  Future<CardioRecordSnapshot> startCardio(String equipmentId) async {
    final session = await _requireActiveSession();
    final record = await _repository.startCardio(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
    state = AsyncData(session);
    return record;
  }

  Future<CardioRecordSnapshot> pauseCardio(String recordId) =>
      _repository.pauseCardio(recordId);

  Future<CardioRecordSnapshot> resumeCardio(String recordId) =>
      _repository.resumeCardio(recordId);

  Future<CardioRecordSnapshot> finishCardio({
    required String recordId,
    double? distanceKm,
  }) async {
    final record = await _repository.finishCardio(
      recordId: recordId,
      distanceKm: distanceKm,
    );
    state = AsyncData(await _requireActiveSession());
    return record;
  }

  Future<WorkoutSessionSummary> summary() async {
    final session = await _repository.getActiveSession();
    if (session == null) {
      throw StateError('進行中のトレーニングがありません');
    }
    return _repository.getSessionSummary(session.id);
  }

  Future<String> complete({String? note}) async {
    final session = await _requireActiveSession();
    await _repository.updateSessionNote(session.id, note);
    await _repository.completeSession(session.id);
    state = const AsyncData(null);
    return session.id;
  }

  Future<WorkoutSessionSnapshot> duplicate(String sourceSessionId) async {
    state = const AsyncLoading();
    try {
      final session = await _repository.duplicateCompletedSession(
        sourceSessionId,
      );
      state = AsyncData(session);
      return session;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<WorkoutSessionSnapshot> _requireActiveSession() async {
    final session = await _repository.getActiveSession();
    if (session == null) {
      throw StateError('進行中のトレーニングがありません');
    }
    return session;
  }
}
