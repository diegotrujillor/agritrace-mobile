import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// `sync_status` of a row deleted locally whose server DELETE has not been
/// confirmed yet (v1.11.5). Such rows are hidden from every list and are
/// never pushed as create/update; [SyncOrchestrator] sends the DELETE and
/// then purges them.
const String kSyncPendingDelete = 'pendingDelete';

/// Statuses excluded from the create/update push: already synced, or a
/// delete tombstone handled separately.
const List<String> _kNotPushedAsUpsert = ['synced', kSyncPendingDelete];

/// Drift SQLite database.
///
/// All four domain tables include `sync_status` + `updated_at` columns so the
/// [SyncOrchestrator] can drain pending changes to the backend and apply
/// server-pulled rows with Last-Write-Wins semantics.
///
/// Schema history:
///   v1 — initial (farms, plots, activities, alerts).
///   v2 — activities.quantity (REAL) + activities.unit (TEXT) for the
///        structured labor record (registro de labores). Existing pilot
///        devices upgrade in place via [migration] — their data is preserved.
@DriftDatabase(tables: [FarmsTable, PlotsTable, ActivitiesTable, AlertsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor over an arbitrary executor (e.g. in-memory).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  /// In-place schema upgrades. Critical for pilot devices that already hold
  /// offline data — we ADD COLUMN rather than recreate, so finca/lote/
  /// actividad rows survive the update.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(activitiesTable, activitiesTable.quantity);
            await m.addColumn(activitiesTable, activitiesTable.unit);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'agritrace');
  }

  // ── Farms ─────────────────────────────────────────────────────────────────

  Future<List<FarmsTableData>> getAllFarms() => (select(farmsTable)
        ..where((t) => t.syncStatus.isNotValue(kSyncPendingDelete)))
      .get();

  Stream<List<FarmsTableData>> watchAllFarms() => (select(farmsTable)
        ..where((t) => t.syncStatus.isNotValue(kSyncPendingDelete)))
      .watch();

  Future<void> upsertFarm(FarmsTableCompanion farm) =>
      into(farmsTable).insertOnConflictUpdate(farm);

  Future<void> deleteFarm(String id) =>
      (delete(farmsTable)..where((t) => t.id.equals(id))).go();

  Future<List<FarmsTableData>> getPendingFarms() => (select(farmsTable)
        ..where((t) => t.syncStatus.isNotIn(_kNotPushedAsUpsert)))
      .get();

  Future<void> markFarmSynced(String id) =>
      (update(farmsTable)..where((t) => t.id.equals(id)))
          .write(const FarmsTableCompanion(syncStatus: Value('synced')));

  // ── Plots ─────────────────────────────────────────────────────────────────

  Stream<List<PlotsTableData>> watchPlotsByFarm(String farmId) =>
      (select(plotsTable)
            ..where((t) =>
                t.farmId.equals(farmId) &
                t.syncStatus.isNotValue(kSyncPendingDelete)))
          .watch();

  Future<List<PlotsTableData>> getPlotsByFarm(String farmId) =>
      (select(plotsTable)
            ..where((t) =>
                t.farmId.equals(farmId) &
                t.syncStatus.isNotValue(kSyncPendingDelete)))
          .get();

  /// One-shot single-plot lookup by id. Used by [PlotRepository.getById]
  /// to power the offline-first plot detail screen (bug #20 fix).
  Future<PlotsTableData?> getPlotById(String id) =>
      (select(plotsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertPlot(PlotsTableCompanion plot) =>
      into(plotsTable).insertOnConflictUpdate(plot);

  Future<void> deletePlot(String id) =>
      (delete(plotsTable)..where((t) => t.id.equals(id))).go();

  Future<List<PlotsTableData>> getPendingPlots() => (select(plotsTable)
        ..where((t) => t.syncStatus.isNotIn(_kNotPushedAsUpsert)))
      .get();

  Future<void> markPlotSynced(String id) =>
      (update(plotsTable)..where((t) => t.id.equals(id)))
          .write(const PlotsTableCompanion(syncStatus: Value('synced')));

  // ── Activities ────────────────────────────────────────────────────────────

  Stream<List<ActivitiesTableData>> watchActivitiesByPlot(String plotId) =>
      (select(activitiesTable)
            ..where((t) =>
                t.plotId.equals(plotId) &
                t.syncStatus.isNotValue(kSyncPendingDelete))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .watch();

  Future<List<ActivitiesTableData>> getActivitiesByPlot(String plotId) =>
      (select(activitiesTable)
            ..where((t) =>
                t.plotId.equals(plotId) &
                t.syncStatus.isNotValue(kSyncPendingDelete)))
          .get();

  Future<void> upsertActivity(ActivitiesTableCompanion activity) =>
      into(activitiesTable).insertOnConflictUpdate(activity);

  Future<ActivitiesTableData?> getActivity(String id) =>
      (select(activitiesTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> deleteActivity(String id) =>
      (delete(activitiesTable)..where((t) => t.id.equals(id))).go();

  Future<List<ActivitiesTableData>> getPendingActivities() =>
      (select(activitiesTable)
            ..where((t) => t.syncStatus.isNotIn(_kNotPushedAsUpsert)))
          .get();

  Future<void> markActivitySynced(String id) =>
      (update(activitiesTable)..where((t) => t.id.equals(id)))
          .write(const ActivitiesTableCompanion(syncStatus: Value('synced')));

  // ── Alerts ────────────────────────────────────────────────────────────────

  Stream<List<AlertsTableData>> watchAlerts() => (select(alertsTable)
        ..where((t) => t.syncStatus.isNotValue(kSyncPendingDelete))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<void> upsertAlert(AlertsTableCompanion alert) =>
      into(alertsTable).insertOnConflictUpdate(alert);

  Future<void> deleteAlertById(String id) =>
      (delete(alertsTable)..where((t) => t.id.equals(id))).go();

  Future<List<AlertsTableData>> getPendingAlerts() => (select(alertsTable)
        ..where((t) => t.syncStatus.isNotIn(_kNotPushedAsUpsert)))
      .get();

  Future<void> markAlertSynced(String id) =>
      (update(alertsTable)..where((t) => t.id.equals(id)))
          .write(const AlertsTableCompanion(syncStatus: Value('synced')));

  // ── Delete tombstones (v1.11.5) ───────────────────────────────────────────

  /// Maps a sync entity name to its table. Entity names are a closed set
  /// from code (never user input), so interpolating the table name into the
  /// SQL below is safe; ids always go through bound variables.
  TableInfo<Table, Object?> _syncTable(String entity) {
    switch (entity) {
      case 'farm':
        return farmsTable;
      case 'plot':
        return plotsTable;
      case 'activity':
        return activitiesTable;
      case 'alert':
        return alertsTable;
    }
    throw ArgumentError.value(entity, 'entity', 'unknown entity');
  }

  /// Local delete. A row that never reached the server (`pendingCreate`) is
  /// removed outright; any other row becomes a hidden [kSyncPendingDelete]
  /// tombstone until [SyncOrchestrator] confirms the server DELETE.
  Future<void> queueDelete(String entity, String id) {
    final table = _syncTable(entity);
    final name = table.actualTableName;
    return transaction(() async {
      await customUpdate(
        'DELETE FROM $name WHERE id = ? AND sync_status = ?',
        variables: [
          Variable.withString(id),
          Variable.withString('pendingCreate')
        ],
        updates: {table},
        updateKind: UpdateKind.delete,
      );
      await customUpdate(
        'UPDATE $name SET sync_status = ? WHERE id = ?',
        variables: [
          Variable.withString(kSyncPendingDelete),
          Variable.withString(id),
        ],
        updates: {table},
        updateKind: UpdateKind.update,
      );
    });
  }

  /// Ids of [entity] rows awaiting their server DELETE.
  Future<List<String>> getPendingDeleteIds(String entity) async {
    final table = _syncTable(entity);
    final rows = await customSelect(
      'SELECT id FROM ${table.actualTableName} WHERE sync_status = ?',
      variables: [Variable.withString(kSyncPendingDelete)],
      readsFrom: {table},
    ).get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Whether [id] is a local delete tombstone.
  Future<bool> isPendingDelete(String entity, String id) async {
    final table = _syncTable(entity);
    final row = await customSelect(
      'SELECT 1 FROM ${table.actualTableName} '
      'WHERE id = ? AND sync_status = ? LIMIT 1',
      variables: [
        Variable.withString(id),
        Variable.withString(kSyncPendingDelete),
      ],
      readsFrom: {table},
    ).getSingleOrNull();
    return row != null;
  }

  /// Hard-deletes [id] (server DELETE confirmed, or row deleted server-side).
  Future<void> purgeRow(String entity, String id) {
    final table = _syncTable(entity);
    return customUpdate(
      'DELETE FROM ${table.actualTableName} WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {table},
      updateKind: UpdateKind.delete,
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Truncates every domain table that holds user-scoped data.
  ///
  /// v1.9.3 — P0 security fix. Drift's SQLite database is shared across
  /// every user that authenticates on the same device, so leaving rows
  /// behind on logout (or before a second account's login) leaks finca,
  /// lote, actividad and alerta data across accounts. Called from
  /// [AuthService.logout] inside a `finally` block (so a failed
  /// `/auth/logout` round-trip still wipes the local DB) and from the
  /// notifier's `login` path whenever the freshly authenticated user id
  /// differs from the last-seen one.
  ///
  /// Wrapped in a single [transaction] so the four `DELETE FROM ...`
  /// statements either all commit or all roll back — partial wipes on
  /// crash are impossible.
  ///
  /// SQLCipher per-user encryption is the long-term fix (Sprint 6+); this
  /// MVP wipe closes the leak without rotating keys.
  Future<void> wipeAllUserData() => transaction(() async {
        await delete(activitiesTable).go();
        await delete(alertsTable).go();
        await delete(plotsTable).go();
        await delete(farmsTable).go();
      });
}
