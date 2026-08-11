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

  Future<WorkoutSessionSnapshot> ensureSession() async {
    state = const AsyncLoading();
    try {
      final session =
          await _repository.getActiveSession() ??
          await _repository.startSession();
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

  Future<WorkoutSessionSummary> summary() async {
    final session = await _repository.getActiveSession();
    if (session == null) {
      throw StateError('進行中のトレーニングがありません');
    }
    return _repository.getSessionSummary(session.id);
  }

  Future<String> complete() async {
    final session = await _repository.getActiveSession();
    if (session == null) {
      throw StateError('進行中のトレーニングがありません');
    }
    await _repository.completeSession(session.id);
    state = const AsyncData(null);
    return session.id;
  }
}
