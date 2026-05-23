import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/plot.dart';

/// Local-first repository for [Plot] entities.
///
/// Writes go to SQLite first with sync metadata; [SyncOrchestrator] pushes
/// pending rows to the backend.  [PlotStatus] is stored as its [.name] string
/// (e.g. `'planning'`, `'growing'`) which matches the backend wire value.
class PlotRepository {
  PlotRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Reactive stream of plots for a given farm.
  Stream<List<Plot>> watchByFarm(String farmId) =>
      _db.watchPlotsByFarm(farmId).map((rows) => rows.map(_fromRow).toList());

  /// One-shot fetch of plots for a given farm.
  Future<List<Plot>> listByFarm(String farmId) async =>
      (await _db.getPlotsByFarm(farmId)).map(_fromRow).toList();

  /// Returns the [Plot] with [id] from the local DB, or `null` when no
  /// row exists. Used by [plotProvider] to power the offline-first detail
  /// screen — see bug #20 in the v1.9.0 backlog.
  Future<Plot?> getById(String id) async {
    final row = await _db.getPlotById(id);
    return row == null ? null : _fromRow(row);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new [Plot] locally and marks it [pendingCreate] for sync.
  Future<Plot> create({
    required String farmId,
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.upsertPlot(PlotsTableCompanion(
      id: Value(id),
      farmId: Value(farmId),
      name: Value(name),
      cropType: Value(cropType),
      status: Value(status.name),
      variety: Value(variety),
      areaHectares: Value(areaHectares),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pendingCreate'),
    ));
    return Plot(
      id: id,
      farmId: farmId,
      name: name,
      cropType: cropType,
      status: status,
      createdAt: now,
      variety: variety,
      areaHectares: areaHectares,
    );
  }

  /// Updates an existing [Plot] locally and marks it [pendingUpdate] for sync.
  Future<Plot> update(
    Plot existing, {
    String? name,
    String? cropType,
    PlotStatus? status,
    String? variety,
    double? areaHectares,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      name: name,
      cropType: cropType,
      status: status,
      variety: variety,
      areaHectares: areaHectares,
    );
    await _db.upsertPlot(PlotsTableCompanion(
      id: Value(existing.id),
      farmId: Value(existing.farmId),
      name: Value(updated.name),
      cropType: Value(updated.cropType),
      status: Value(updated.status.name),
      variety: Value(updated.variety),
      areaHectares: Value(updated.areaHectares),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(now),
      syncStatus: const Value('pendingUpdate'),
    ));
    return updated;
  }

  /// Deletes a plot from the local DB immediately.
  Future<void> delete(String id) => _db.deletePlot(id);

  // ── Sync helpers ──────────────────────────────────────────────────────────

  /// Returns all rows whose [syncStatus] is not `'synced'`.
  Future<List<PlotsTableData>> getPending() => _db.getPendingPlots();

  /// Marks a row as `'synced'` after the backend accepted the change.
  Future<void> markSynced(String id) => _db.markPlotSynced(id);

  /// Upserts a row received from the server pull leg (LWW — server wins).
  Future<void> upsertFromServer(Map<String, dynamic> data) async {
    final row = Plot.fromJson(data);
    final updatedAt = data['updatedAt'] != null
        ? DateTime.parse(data['updatedAt'] as String)
        : row.createdAt;
    await _db.upsertPlot(PlotsTableCompanion(
      id: Value(row.id),
      farmId: Value(row.farmId),
      name: Value(row.name),
      cropType: Value(row.cropType),
      status: Value(row.status.name),
      variety: Value(row.variety),
      areaHectares: Value(row.areaHectares),
      createdAt: Value(row.createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: const Value('synced'),
    ));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  static Plot _fromRow(PlotsTableData r) => Plot(
        id: r.id,
        farmId: r.farmId,
        name: r.name,
        cropType: r.cropType,
        status: PlotStatus.fromName(r.status),
        createdAt: r.createdAt,
        variety: r.variety,
        areaHectares: r.areaHectares,
      );
}
