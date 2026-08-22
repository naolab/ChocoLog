import 'package:chocolog/core/database/app_database.dart';
import 'package:drift/drift.dart';

enum SyncOperation { upsert, delete }

class SyncOutboxRepository {
  SyncOutboxRepository(this._database);

  final AppDatabase _database;

  Future<void> enqueueUpsert(String sessionId) =>
      _enqueue(sessionId: sessionId, operation: SyncOperation.upsert);

  Future<void> enqueueDelete(String sessionId) =>
      _enqueue(sessionId: sessionId, operation: SyncOperation.delete);

  Future<List<SyncOutboxRow>> pending({int limit = 20}) {
    final query = _database.select(_database.syncOutbox)
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
      ..limit(limit);
    return query.get();
  }

  Future<int> pendingCount() async {
    final count = _database.syncOutbox.id.count();
    return (await (_database.selectOnly(
      _database.syncOutbox,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).getSingle());
  }

  Future<void> markSynced(int id) async {
    await (_database.delete(
      _database.syncOutbox,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<void> markFailed(int id, Object error) async {
    final current = await (_database.select(
      _database.syncOutbox,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (current == null) return;
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.syncOutbox,
    )..where((row) => row.id.equals(id))).write(
      SyncOutboxCompanion(
        attemptCount: Value(current.attemptCount + 1),
        lastError: Value(error.toString()),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> clearError(int id) async {
    await (_database.update(_database.syncOutbox)
          ..where((row) => row.id.equals(id)))
        .write(const SyncOutboxCompanion(lastError: Value(null)));
  }

  Future<void> _enqueue({
    required String sessionId,
    required SyncOperation operation,
  }) async {
    final now = DateTime.now().toUtc();
    final existing =
        await (_database.select(_database.syncOutbox)..where(
              (row) =>
                  row.entityType.equals('workout_session') &
                  row.entityId.equals(sessionId),
            ))
            .getSingleOrNull();
    if (existing != null && existing.operation == operation.name) return;
    if (existing != null) {
      await (_database.update(
        _database.syncOutbox,
      )..where((row) => row.id.equals(existing.id))).write(
        SyncOutboxCompanion(
          operation: Value(operation.name),
          attemptCount: const Value(0),
          lastError: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return;
    }
    await _database
        .into(_database.syncOutbox)
        .insertOnConflictUpdate(
          SyncOutboxCompanion.insert(
            entityType: 'workout_session',
            entityId: sessionId,
            operation: operation.name,
            attemptCount: const Value(0),
            lastError: const Value(null),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }
}
