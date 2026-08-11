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
    final session = await ensureSession();
    await _repository.addExerciseSets(
      sessionId: session.id,
      equipmentId: equipmentId,
      sets: sets,
    );
    return _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }

  Future<List<ExerciseSetValue>> currentSets(String equipmentId) async {
    final session = await ensureSession();
    return _repository.getSessionSets(
      sessionId: session.id,
      equipmentId: equipmentId,
    );
  }
}
