import 'package:drift/drift.dart';

/// Sync lifecycle for a locally persisted row.
///
/// `synced`        — row matches the server.
/// `pendingCreate` — row created offline; push required.
/// `pendingUpdate` — row modified offline; push required.
/// `pendingDelete` — row tombstoned offline; push required then hard-delete.
enum SyncStatus { synced, pendingCreate, pendingUpdate, pendingDelete }

/// SQLite table for [Farm] entities.
class FarmsTable extends Table {
  @override
  String get tableName => 'farms';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get cropType => text().named('crop_type')();
  RealColumn get areaHectares => real().named('area_hectares')();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  /// Wire value of [SyncStatus] (e.g. `'synced'`, `'pendingCreate'`).
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// SQLite table for [Plot] entities.
class PlotsTable extends Table {
  @override
  String get tableName => 'plots';

  TextColumn get id => text()();
  TextColumn get farmId => text().named('farm_id')();
  TextColumn get name => text()();
  TextColumn get cropType => text().named('crop_type')();
  TextColumn get status =>
      text().withDefault(const Constant('planning'))();
  TextColumn get variety => text().nullable()();
  RealColumn get areaHectares => real().named('area_hectares').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// SQLite table for [Activity] entities.
class ActivitiesTable extends Table {
  @override
  String get tableName => 'activities';

  TextColumn get id => text()();
  TextColumn get plotId => text().named('plot_id')();
  TextColumn get type => text()();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  TextColumn get description => text().nullable()();
  TextColumn get photoUrl => text().named('photo_url').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// SQLite table for [Alert] entities.
class AlertsTable extends Table {
  @override
  String get tableName => 'alerts';

  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get severity => text()();
  TextColumn get title => text()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  TextColumn get plotId => text().named('plot_id').nullable()();
  TextColumn get body => text().nullable()();
  DateTimeColumn get scheduledFor =>
      dateTime().named('scheduled_for').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
