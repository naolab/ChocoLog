import 'package:chocolog/core/supabase/supabase_service.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseFriendHistoryRepositoryProvider =
    Provider<SupabaseFriendHistoryRepository>(
      (ref) => SupabaseFriendHistoryRepository(),
    );

class SupabaseFriendHistoryRepository {
  SupabaseClient get _client =>
      SupabaseService.client ??
      (throw StateError('Supabase has not been initialized'));

  Future<List<WorkoutSessionSummary>> load(String ownerId) async {
    final sessionRows = await _client
        .from('workout_sessions')
        .select('id, studio_id, status, started_at, ended_at')
        .eq('owner_id', ownerId)
        .eq('status', 'completed')
        .isFilter('deleted_at', null)
        .order('started_at', ascending: false);
    if (sessionRows.isEmpty) return const [];

    final sessionIds = [for (final row in sessionRows) row['id'] as String];
    final recordRows = await _client
        .from('exercise_records')
        .select(
          'id, workout_session_id, equipment_id, record_type, timer_status, duration_seconds, distance_km, sort_order',
        )
        .inFilter('workout_session_id', sessionIds)
        .order('sort_order');
    final recordIds = [for (final row in recordRows) row['id'] as String];
    final setRows = recordIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _client
              .from('exercise_sets')
              .select('id, exercise_record_id, set_number, weight_kg, reps')
              .inFilter('exercise_record_id', recordIds)
              .order('set_number');

    final setsByRecord = <String, List<ExerciseSetValue>>{};
    for (final row in setRows) {
      setsByRecord
          .putIfAbsent(row['exercise_record_id'] as String, () => [])
          .add(
            ExerciseSetValue(
              id: row['id'] as String,
              setNumber: row['set_number'] as int,
              weightKg: row['weight_kg'] as int?,
              reps: row['reps'] as int,
            ),
          );
    }
    final equipmentNames = {
      for (final item in EquipmentRepository.defaultEquipment)
        item.id: item.name,
    };
    final recordsBySession = <String, List<Map<String, dynamic>>>{};
    for (final row in recordRows) {
      recordsBySession
          .putIfAbsent(row['workout_session_id'] as String, () => [])
          .add(row);
    }

    return [
      for (final row in sessionRows)
        WorkoutSessionSummary(
          session: WorkoutSessionSnapshot(
            id: row['id'] as String,
            studioId: row['studio_id'] as String?,
            status: row['status'] as String,
            startedAt: DateTime.parse(row['started_at'] as String),
            endedAt: row['ended_at'] == null
                ? null
                : DateTime.parse(row['ended_at'] as String),
            note: null,
          ),
          exercises: [
            for (final record
                in recordsBySession[row['id'] as String] ?? const [])
              WorkoutExerciseSummary(
                recordId: record['id'] as String,
                equipmentId: record['equipment_id'] as String,
                equipmentName:
                    equipmentNames[record['equipment_id'] as String] ??
                    record['equipment_id'] as String,
                recordType: record['record_type'] as String,
                sets: setsByRecord[record['id'] as String] ?? const [],
                durationSeconds: record['duration_seconds'] as int?,
                distanceKm: (record['distance_km'] as num?)?.toDouble(),
                timerStatus: record['timer_status'] as String,
              ),
          ],
        ),
    ];
  }
}
