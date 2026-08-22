import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
import 'package:chocolog/core/sync/supabase_sync_repository.dart';
import 'package:chocolog/core/sync/sync_outbox_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository(ref.watch(databaseProvider));
});

final activeEquipmentProvider = StreamProvider<List<EquipmentItem>>((
  ref,
) async* {
  final repository = ref.watch(equipmentRepositoryProvider);
  await repository.seedDefaults();
  yield* repository.watchActive();
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(databaseProvider));
});

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((ref) {
  return SyncOutboxRepository(ref.watch(databaseProvider));
});

final supabaseSyncRepositoryProvider = Provider<SupabaseSyncRepository>((ref) {
  return SupabaseSyncRepository(
    ref.watch(workoutRepositoryProvider),
    ref.watch(syncOutboxRepositoryProvider),
  );
});
