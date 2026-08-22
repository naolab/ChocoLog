import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('共有履歴のモデルはローカル履歴と同じ集計を使える', () {
    final summary = WorkoutSessionSummary(
      session: WorkoutSessionSnapshot(
        id: 'session-1',
        studioId: null,
        status: 'completed',
        startedAt: DateTime.utc(2026, 8, 22),
        endedAt: DateTime.utc(2026, 8, 22, 1),
        note: null,
      ),
      exercises: [
        WorkoutExerciseSummary(
          recordId: 'record-1',
          equipmentId: 'chest-press',
          equipmentName: 'チェストプレス',
          recordType: 'strength',
          sets: const [
            ExerciseSetValue(id: 'set-1', setNumber: 1, weightKg: 20, reps: 15),
            ExerciseSetValue(id: 'set-2', setNumber: 2, weightKg: 20, reps: 15),
          ],
          durationSeconds: null,
          distanceKm: null,
          timerStatus: 'notStarted',
        ),
      ],
    );

    expect(summary.totalSetCount, 2);
    expect(summary.totalCardioSeconds, 0);
    expect(summary.session.status, 'completed');
  });
}
