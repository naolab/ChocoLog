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
          await _repository.reopenTodaySession(studioId: studioId) ??
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
    String? studioId,
  }) async {
    state = const AsyncLoading();
    try {
      final session = await _editableTodaySession(studioId: studioId);
      await _repository.addExerciseSets(
        sessionId: session.id,
        equipmentId: equipmentId,
        sets: sets,
      );
      final savedSets = await _repository.getSessionSets(
        sessionId: session.id,
        equipmentId: equipmentId,
      );
      await _repository.completeSession(session.id);
      state = const AsyncData(null);
      return savedSets;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<ExerciseSetValue>> currentSets(String equipmentId) async {
    final session = await _repository.getTodaySession();
    if (session == null) return const [];
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
    final session = await _editableTodaySession();
    await _repository.updateExerciseSet(
      setId: setId,
      weightKg: weightKg,
      reps: reps,
    );
    final saved = await _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
    await _repository.completeSession(session.id);
    state = const AsyncData(null);
    return saved;
  }

  Future<List<ExerciseSetValue>> deleteSet({
    required String equipmentId,
    required String setId,
  }) async {
    final session = await _editableTodaySession();
    await _repository.deleteExerciseSet(setId);
    final saved = await _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
    final summary = await _repository.getSessionSummary(session.id);
    if (summary.exercises.isEmpty) {
      await _repository.deleteEmptyDraftSession(session.id);
    } else {
      await _repository.completeSession(session.id);
    }
    state = const AsyncData(null);
    return saved;
  }

  Future<CardioRecordSnapshot?> currentCardio(String equipmentId) async {
    final session = await _repository.getTodaySession();
    if (session == null) return null;
    return _repository.getCardioRecord(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }

  Future<CardioRecordSnapshot> startCardio(
    String equipmentId, {
    String? studioId,
  }) async {
    final session = await _editableTodaySession(studioId: studioId);
    final record = await _repository.startCardio(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
    state = AsyncData(session);
    return record;
  }

  Future<CardioRecordSnapshot> addManualCardio({
    required String equipmentId,
    required int durationMinutes,
    double? distanceKm,
    String? studioId,
  }) async {
    state = const AsyncLoading();
    try {
      final session = await _editableTodaySession(studioId: studioId);
      final record = await _repository.addManualCardio(
        sessionId: session.id,
        equipmentId: equipmentId,
        durationSeconds: durationMinutes * 60,
        distanceKm: distanceKm,
      );
      await _repository.completeSession(session.id);
      state = const AsyncData(null);
      return record;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
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
    await _repository.completeSession(record.sessionId);
    state = const AsyncData(null);
    return record;
  }

  Future<void> finalizeSavedSession() async {
    final session = await _repository.getActiveSession();
    if (session == null) return;
    final summary = await _repository.getSessionSummary(session.id);
    if (summary.exercises.isEmpty) {
      await _repository.deleteEmptyDraftSession(session.id);
      state = const AsyncData(null);
      return;
    }
    try {
      await _repository.completeSession(session.id);
    } on StateError {
      // 計測中の有酸素記録は、終了操作まで進行中のまま維持する。
      return;
    }
    state = const AsyncData(null);
  }

  void notifyRecordsChanged() {
    state = const AsyncLoading();
    state = const AsyncData(null);
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

  Future<void> duplicate(String sourceSessionId) async {
    state = const AsyncLoading();
    try {
      final session = await _repository.duplicateCompletedSession(
        sourceSessionId,
      );
      await _repository.completeSession(session.id);
      state = const AsyncData(null);
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

  Future<WorkoutSessionSnapshot> _editableTodaySession({
    String? studioId,
  }) async {
    final today = await _repository.getTodaySession();
    if (today?.status == 'draft') return today!;
    return await _repository.reopenTodaySession(studioId: studioId) ??
        await _repository.startSession(studioId: studioId);
  }
}
