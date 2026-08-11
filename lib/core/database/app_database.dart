import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('EquipmentRow')
class Equipment extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get metricType => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  TextColumn get studioId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExerciseRecordRow')
class ExerciseRecords extends Table {
  TextColumn get id => text()();
  TextColumn get workoutSessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId => text().references(Equipment, #id)();
  TextColumn get recordType => text()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get pausedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get accumulatedPausedSeconds =>
      integer().withDefault(const Constant(0))();
  TextColumn get timerStatus =>
      text().withDefault(const Constant('notStarted'))();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceKm => real().nullable()();
  RealColumn get speedKph => real().nullable()();
  RealColumn get incline => real().nullable()();
  IntColumn get resistance => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExerciseSetRow')
class ExerciseSets extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseRecordId =>
      text().references(ExerciseRecords, #id, onDelete: KeyAction.cascade)();
  IntColumn get setNumber => integer()();
  IntColumn get weightKg => integer().nullable()();
  IntColumn get reps => integer()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {exerciseRecordId, setNumber},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (set_number > 0)',
    'CHECK (reps > 0)',
    'CHECK (weight_kg IS NULL OR (weight_kg >= 0 AND weight_kg % 5 = 0))',
  ];
}

@DriftDatabase(
  tables: [Equipment, WorkoutSessions, ExerciseRecords, ExerciseSets],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'chocolog'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
