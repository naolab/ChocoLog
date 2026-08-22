import 'package:chocolog/core/database/app_database.dart';
import 'package:chocolog/core/sync/sync_outbox_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SyncOutboxRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = SyncOutboxRepository(database);
  });

  tearDown(() => database.close());

  test('同じセッションの同期キューは重複せず、操作変更時だけ再送状態をリセットする', () async {
    await repository.enqueueUpsert('session-1');
    await repository.enqueueUpsert('session-1');

    var pending = await repository.pending();
    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOperation.upsert.name);

    await repository.markFailed(pending.single.id, StateError('offline'));
    pending = await repository.pending();
    expect(pending.single.attemptCount, 1);
    expect(pending.single.lastError, contains('offline'));

    await repository.enqueueUpsert('session-1');
    pending = await repository.pending();
    expect(pending.single.attemptCount, 1);

    await repository.enqueueDelete('session-1');
    pending = await repository.pending();
    expect(pending.single.operation, SyncOperation.delete.name);
    expect(pending.single.attemptCount, 0);
    expect(await repository.pendingCount(), 1);
  });

  test('同期済みのキューを削除できる', () async {
    await repository.enqueueUpsert('session-1');
    final row = (await repository.pending()).single;

    await repository.markSynced(row.id);

    expect(await repository.pending(), isEmpty);
    expect(await repository.pendingCount(), 0);
  });
}
