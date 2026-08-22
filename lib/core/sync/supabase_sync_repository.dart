import 'package:chocolog/core/supabase/supabase_service.dart';
import 'package:chocolog/core/sync/sync_outbox_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncResult {
  const SyncResult({
    required this.synced,
    required this.failed,
    required this.pending,
  });

  const SyncResult.notAuthenticated({required this.pending})
    : synced = 0,
      failed = 0;

  final int synced;
  final int failed;
  final int pending;

  bool get isSuccessful => failed == 0;
}

class SupabaseSyncRepository {
  SupabaseSyncRepository(this._workoutRepository, this._outbox);

  final WorkoutRepository _workoutRepository;
  final SyncOutboxRepository _outbox;
  Future<SyncResult>? _syncInFlight;

  SupabaseClient? get _client => SupabaseService.client;

  Future<void> enqueueAllCompletedSessions() async {
    final sessions = await _workoutRepository.getCompletedSessionSummaries();
    for (final summary in sessions) {
      await _outbox.enqueueUpsert(summary.session.id);
    }
  }

  Future<SyncResult> syncPending() {
    final ongoing = _syncInFlight;
    if (ongoing != null) return ongoing;
    final future = _syncPending();
    _syncInFlight = future;
    return future.whenComplete(() => _syncInFlight = null);
  }

  Future<SyncResult> _syncPending() async {
    final client = _client;
    final pendingBefore = await _outbox.pendingCount();
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return SyncResult.notAuthenticated(pending: pendingBefore);
    }

    await enqueueAllCompletedSessions();
    final rows = await _outbox.pending();
    var synced = 0;
    var failed = 0;
    for (final row in rows) {
      try {
        if (row.operation == SyncOperation.delete.name) {
          await _deleteRemoteSession(client, row.entityId, user.id);
        } else {
          final summary = await _workoutRepository.getSessionSummary(
            row.entityId,
          );
          if (summary.session.status != 'completed') continue;
          await _upsertRemoteSession(client, user.id, summary);
        }
        await _outbox.markSynced(row.id);
        synced++;
      } on StateError catch (error) {
        // A draft session is intentionally kept local until it is completed.
        if (error.message == 'sync_deferred') continue;
        await _outbox.markFailed(row.id, error);
        failed++;
      } catch (error) {
        await _outbox.markFailed(row.id, error);
        failed++;
      }
    }
    return SyncResult(
      synced: synced,
      failed: failed,
      pending: await _outbox.pendingCount(),
    );
  }

  Future<void> _upsertRemoteSession(
    SupabaseClient client,
    String ownerId,
    WorkoutSessionSummary summary,
  ) async {
    final session = summary.session;
    if (session.status != 'completed') {
      throw StateError('sync_deferred');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await client.from('workout_sessions').upsert({
      'id': session.id,
      'owner_id': ownerId,
      // Studio and memo are intentionally not part of the shared history.
      'studio_id': null,
      'status': 'completed',
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'ended_at': session.endedAt?.toUtc().toIso8601String(),
      'note': null,
      'updated_at': now,
      'deleted_at': null,
    });

    // Replacing child rows makes local deletions idempotent without a second
    // tombstone table for every set and exercise record.
    await client
        .from('exercise_records')
        .delete()
        .eq('workout_session_id', session.id);

    for (final (index, exercise) in summary.exercises.indexed) {
      await client.from('exercise_records').upsert({
        'id': exercise.recordId,
        'workout_session_id': session.id,
        'equipment_id': exercise.equipmentId,
        'record_type': exercise.recordType,
        'timer_status': exercise.timerStatus,
        'duration_seconds': exercise.durationSeconds,
        'distance_km': exercise.distanceKm,
        'sort_order': index,
        'note': null,
        'updated_at': now,
      });

      if (exercise.sets.isEmpty) continue;
      if (exercise.sets.any((set) => set.id == null)) {
        throw StateError('同期対象のセットIDがありません');
      }
      await client.from('exercise_sets').insert([
        for (final set in exercise.sets)
          {
            'id': set.id!,
            'exercise_record_id': exercise.recordId,
            'set_number': set.setNumber,
            'weight_kg': set.weightKg,
            'reps': set.reps,
            'updated_at': now,
          },
      ]);
    }
  }

  Future<void> _deleteRemoteSession(
    SupabaseClient client,
    String sessionId,
    String ownerId,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await client
        .from('workout_sessions')
        .update({'deleted_at': now, 'updated_at': now})
        .eq('id', sessionId)
        .eq('owner_id', ownerId);
  }
}
