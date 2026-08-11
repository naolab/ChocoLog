import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/features/equipment/data/equipment_repository.dart';
import 'package:chocolog/features/workout/data/workout_repository.dart';
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
