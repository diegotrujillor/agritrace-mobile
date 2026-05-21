import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/farm.dart';

/// Local-first repository for [Farm] entities.
///
/// All writes go to SQLite first with the appropriate [SyncStatus] flag.
/// [SyncOrchestrator] drains pending rows to the backend and calls
/// [markSynced] on success.  Reads are immutable [Farm] value objects
/// produced from the Drift-generated [FarmsTableData] rows.
class FarmRepository {
  FarmRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Reactive stream of all farms, ordered by DB insertion order.
  Stream<List<Farm>> watchAll() =>
      _db.watchAllFarms().map((rows) => rows.map(_fromRow).toList());

  /// One-shot fetch of all farms.
  Future<List<Farm>> listAll() async =>
      (await _db.getAllFarms()).map(_fromRow).toList();

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new [Farm] locally and marks it [pendingCreate] for sync.
  Future<Farm> create({
    required String name,
    required String cropType,
    required double areaHectares,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.upsertFarm(FarmsTableCompanion(
      id: Value(id),
      name: Value(name),
      cropType: Value(cropType),
      areaHectares: Value(areaHectares),
      latitude: Value(latitude),
      longitude: Value(longitude),
      address: Value(address),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pendingCreate'),
    ));
    return Farm(
      id: id,
      name: name,
      cropType: cropType,
      areaHectares: areaHectares,
      createdAt: now,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  /// Updates an existing [Farm] locally and marks it [pendingUpdate] for sync.
  Future<Farm> update(
    Farm existing, {
    String? name,
    String? cropType,
    double? areaHectares,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      name: name,
      cropType: cropType,
      areaHectares: areaHectares,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    await _db.upsertFarm(FarmsTableCompanion(
      id: Value(existing.id),
      name: Value(updated.name),
      cropType: Value(updated.cropType),
      areaHectares: Value(updated.areaHectares),
      latitude: Value(updated.latitude),
      longitude: Value(updated.longitude),
      address: Value(updated.address),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(now),
      syncStatus: const Value('pendingUpdate'),
    ));
    return updated;
  }

  /// Deletes a farm from the local DB immediately.
  ///
  /// Tombstone push (pendingDelete) is a later enhancement; for MVP the
  /// delete is also queued as an implicit server DELETE via sync if the row
  /// was previously synced.
  Future<void> delete(String id) => _db.deleteFarm(id);

  // ── Sync helpers ──────────────────────────────────────────────────────────

  /// Returns all rows whose [syncStatus] is not `'synced'`.
  Future<List<FarmsTableData>> getPending() => _db.getPendingFarms();

  /// Marks a row as `'synced'` after the backend accepted the change.
  Future<void> markSynced(String id) => _db.markFarmSynced(id);

  /// Upserts a row received from the server pull leg (LWW — server wins).
  Future<void> upsertFromServer(Map<String, dynamic> data) async {
    final row = Farm.fromJson(data);
    final updatedAt = data['updatedAt'] != null
        ? DateTime.parse(data['updatedAt'] as String)
        : row.createdAt;
    await _db.upsertFarm(FarmsTableCompanion(
      id: Value(row.id),
      name: Value(row.name),
      cropType: Value(row.cropType),
      areaHectares: Value(row.areaHectares),
      latitude: Value(row.latitude),
      longitude: Value(row.longitude),
      address: Value(row.address),
      createdAt: Value(row.createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: const Value('synced'),
    ));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  static Farm _fromRow(FarmsTableData r) => Farm(
        id: r.id,
        name: r.name,
        cropType: r.cropType,
        areaHectares: r.areaHectares,
        createdAt: r.createdAt,
        latitude: r.latitude,
        longitude: r.longitude,
        address: r.address,
      );
}
