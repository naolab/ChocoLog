import 'package:chocolog/core/database/app_database.dart';
import 'package:drift/drift.dart';

class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    required this.metricType,
  });

  final String id;
  final String name;
  final String category;
  final String metricType;
}

class EquipmentRepository {
  EquipmentRepository(this._database);

  final AppDatabase _database;

  static const defaultEquipment = [
    EquipmentItem(
      id: 'shoulder-press',
      name: 'ショルダープレス',
      category: 'upperBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'chest-press',
      name: 'チェストプレス',
      category: 'upperBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'lat-pulldown',
      name: 'ラットプルダウン',
      category: 'upperBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'biceps-curl',
      name: 'バイセップスカール',
      category: 'upperBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'dips',
      name: 'ディップス',
      category: 'upperBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'abdominal-trainer',
      name: 'アブドミナルトレーナー',
      category: 'core',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'ab-bench',
      name: 'アブベンチ',
      category: 'core',
      metricType: 'bodyweight',
    ),
    EquipmentItem(
      id: 'leg-press',
      name: 'レッグプレス',
      category: 'lowerBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'adduction',
      name: 'アダクション',
      category: 'lowerBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'abduction',
      name: 'アブダクション',
      category: 'lowerBody',
      metricType: 'strength',
    ),
    EquipmentItem(
      id: 'treadmill',
      name: 'トレッドミル',
      category: 'cardio',
      metricType: 'cardio',
    ),
    EquipmentItem(
      id: 'bike',
      name: 'バイク',
      category: 'cardio',
      metricType: 'cardio',
    ),
  ];

  Future<void> seedDefaults() async {
    await _database.batch((batch) {
      batch.insertAll(_database.equipment, [
        for (final (index, item) in defaultEquipment.indexed)
          EquipmentCompanion.insert(
            id: item.id,
            name: item.name,
            category: item.category,
            metricType: item.metricType,
            sortOrder: Value(index),
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  Stream<List<EquipmentItem>> watchActive() {
    final query = _database.select(_database.equipment)
      ..where((row) => row.isActive.equals(true))
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => EquipmentItem(
              id: row.id,
              name: row.name,
              category: row.category,
              metricType: row.metricType,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<EquipmentItem?> findById(String id) async {
    final query = _database.select(_database.equipment)
      ..where((row) => row.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return EquipmentItem(
      id: row.id,
      name: row.name,
      category: row.category,
      metricType: row.metricType,
    );
  }
}
