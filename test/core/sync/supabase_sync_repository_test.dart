import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/core/sync/supabase_sync_repository.dart';
import 'package:chocolog/core/sync/sync_outbox_repository.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late WorkoutRepository workoutRepository;
  late SyncOutboxRepository outbox;
  late SupabaseSyncRepository syncRepository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await EquipmentRepository(database).seedDefaults();
    workoutRepository = WorkoutRepository(database);
    outbox = SyncOutboxRepository(database);
    syncRepository = SupabaseSyncRepository(workoutRepository, outbox);
  });

  tearDown(() => database.close());

  test('未ログイン時はローカルの未同期キューを保持する', () async {
    final session = await workoutRepository.startSession();
    await workoutRepository.addExerciseSets(
      sessionId: session.id,
      equipmentId: 'chest-press',
      sets: const [ExerciseSetValue(weightKg: 20, reps: 15)],
    );
    await workoutRepository.completeSession(session.id);

    final result = await syncRepository.syncPending();

    expect(result.synced, 0);
    expect(result.failed, 0);
    expect(result.pending, 1);
    expect(await outbox.pending(), hasLength(1));
  });
}
