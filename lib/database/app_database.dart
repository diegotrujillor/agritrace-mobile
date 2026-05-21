import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Drift SQLite database. Schema version 1 — offline-first persistence.
///
/// All four domain tables include `sync_status` + `updated_at` columns so the
/// [SyncOrchestrator] can drain pending changes to the backend and apply
/// server-pulled rows with Last-Write-Wins semantics.
@DriftDatabase(tables: [FarmsTable, PlotsTable, ActivitiesTable, AlertsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'agritrace');
  }

  // ── Farms ─────────────────────────────────────────────────────────────────

  Future<List<FarmsTableData>> getAllFarms() =>
      select(farmsTable).get();

  Stream<List<FarmsTableData>> watchAllFarms() =>
      select(farmsTable).watch();

  Future<void> upsertFarm(FarmsTableCompanion farm) =>
      into(farmsTable).insertOnConflictUpdate(farm);

  Future<void> deleteFarm(String id) =>
      (delete(farmsTable)..where((t) => t.id.equals(id))).go();

  Future<List<FarmsTableData>> getPendingFarms() =>
      (select(farmsTable)
            ..where((t) => t.syncStatus.isNotValue('synced')))
          .get();

  Future<void> markFarmSynced(String id) =>
      (update(farmsTable)..where((t) => t.id.equals(id)))
          .write(const FarmsTableCompanion(syncStatus: Value('synced')));

  // ── Plots ─────────────────────────────────────────────────────────────────

  Stream<List<PlotsTableData>> watchPlotsByFarm(String farmId) =>
      (select(plotsTable)..where((t) => t.farmId.equals(farmId))).watch();

  Future<List<PlotsTableData>> getPlotsByFarm(String farmId) =>
      (select(plotsTable)..where((t) => t.farmId.equals(farmId))).get();

  Future<void> upsertPlot(PlotsTableCompanion plot) =>
      into(plotsTable).insertOnConflictUpdate(plot);

  Future<void> deletePlot(String id) =>
      (delete(plotsTable)..where((t) => t.id.equals(id))).go();

  Future<List<PlotsTableData>> getPendingPlots() =>
      (select(plotsTable)
            ..where((t) => t.syncStatus.isNotValue('synced')))
          .get();

  Future<void> markPlotSynced(String id) =>
      (update(plotsTable)..where((t) => t.id.equals(id)))
          .write(const PlotsTableCompanion(syncStatus: Value('synced')));

  // ── Activities ────────────────────────────────────────────────────────────

  Stream<List<ActivitiesTableData>> watchActivitiesByPlot(String plotId) =>
      (select(activitiesTable)
            ..where((t) => t.plotId.equals(plotId))
            ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
          .watch();

  Future<List<ActivitiesTableData>> getActivitiesByPlot(String plotId) =>
      (select(activitiesTable)
            ..where((t) => t.plotId.equals(plotId)))
          .get();

  Future<void> upsertActivity(ActivitiesTableCompanion activity) =>
      into(activitiesTable).insertOnConflictUpdate(activity);

  Future<void> deleteActivity(String id) =>
      (delete(activitiesTable)..where((t) => t.id.equals(id))).go();

  Future<List<ActivitiesTableData>> getPendingActivities() =>
      (select(activitiesTable)
            ..where((t) => t.syncStatus.isNotValue('synced')))
          .get();

  Future<void> markActivitySynced(String id) =>
      (update(activitiesTable)..where((t) => t.id.equals(id)))
          .write(
              const ActivitiesTableCompanion(syncStatus: Value('synced')));

  // ── Alerts ────────────────────────────────────────────────────────────────

  Stream<List<AlertsTableData>> watchAlerts() =>
      (select(alertsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertAlert(AlertsTableCompanion alert) =>
      into(alertsTable).insertOnConflictUpdate(alert);

  Future<void> deleteAlertById(String id) =>
      (delete(alertsTable)..where((t) => t.id.equals(id))).go();

  Future<List<AlertsTableData>> getPendingAlerts() =>
      (select(alertsTable)
            ..where((t) => t.syncStatus.isNotValue('synced')))
          .get();

  Future<void> markAlertSynced(String id) =>
      (update(alertsTable)..where((t) => t.id.equals(id)))
          .write(const AlertsTableCompanion(syncStatus: Value('synced')));
}
