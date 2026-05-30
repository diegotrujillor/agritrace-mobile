import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/activity.dart';

/// Local-first repository for [Activity] entities.
///
/// Writes go to SQLite first with sync metadata.  The [ActivityType] enum is
/// stored using its snake_case wire value (e.g. `'pest_control'`) so the DB
/// column stays in sync with the backend enum — mapped back via
/// [ActivityType.fromWire] when reading.
class ActivityRepository {
  ActivityRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Reactive stream of activities for a given plot, newest first.
  Stream<List<Activity>> watchByPlot(String plotId) =>
      _db
          .watchActivitiesByPlot(plotId)
          .map((rows) => rows.map(_fromRow).toList());

  /// One-shot fetch of activities for a given plot.
  Future<List<Activity>> listByPlot(String plotId) async =>
      (await _db.getActivitiesByPlot(plotId)).map(_fromRow).toList();

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new [Activity] locally and marks it [pendingCreate] for sync.
  Future<Activity> create({
    required String plotId,
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.upsertActivity(ActivitiesTableCompanion(
      id: Value(id),
      plotId: Value(plotId),
      type: Value(type.wire),
      occurredAt: Value(occurredAt.toUtc()),
      description: Value(description),
      photoUrl: Value(photoUrl),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pendingCreate'),
    ));
    return Activity(
      id: id,
      plotId: plotId,
      type: type,
      occurredAt: occurredAt,
      createdAt: now,
      description: description,
      photoUrl: photoUrl,
    );
  }

  /// Updates an existing [Activity] locally and marks it [pendingUpdate].
  Future<Activity> update(
    Activity existing, {
    ActivityType? type,
    DateTime? occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      type: type,
      occurredAt: occurredAt,
      description: description,
      photoUrl: photoUrl,
    );
    await _db.upsertActivity(ActivitiesTableCompanion(
      id: Value(existing.id),
      plotId: Value(existing.plotId),
      type: Value(updated.type.wire),
      occurredAt: Value(updated.occurredAt.toUtc()),
      description: Value(updated.description),
      photoUrl: Value(updated.photoUrl),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(now),
      syncStatus: const Value('pendingUpdate'),
    ));
    return updated;
  }

  /// Deletes an activity from the local DB immediately.
  Future<void> delete(String id) => _db.deleteActivity(id);

  /// One-shot read from local Drift by primary key. Returns `null` when
  /// the activity is unknown locally (e.g. deep-link to an id that was
  /// never pulled). Callers that need a remote round-trip on miss should
  /// fall back to [ActivityService.get] explicitly.
  Future<Activity?> getById(String id) async {
    final row = await _db.getActivity(id);
    return row == null ? null : _fromRow(row);
  }

  // ── Sync helpers ──────────────────────────────────────────────────────────

  /// Returns all rows whose [syncStatus] is not `'synced'`.
  Future<List<ActivitiesTableData>> getPending() =>
      _db.getPendingActivities();

  /// Marks a row as `'synced'` after the backend accepted the change.
  Future<void> markSynced(String id) => _db.markActivitySynced(id);

  /// Upserts a row received from the server pull leg (LWW — server wins).
  Future<void> upsertFromServer(Map<String, dynamic> data) async {
    final row = Activity.fromJson(data);
    final updatedAt = data['updatedAt'] != null
        ? DateTime.parse(data['updatedAt'] as String)
        : row.createdAt;
    await _db.upsertActivity(ActivitiesTableCompanion(
      id: Value(row.id),
      plotId: Value(row.plotId),
      type: Value(row.type.wire),
      occurredAt: Value(row.occurredAt),
      description: Value(row.description),
      photoUrl: Value(row.photoUrl),
      createdAt: Value(row.createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: const Value('synced'),
    ));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  static Activity _fromRow(ActivitiesTableData r) => Activity(
        id: r.id,
        plotId: r.plotId,
        type: ActivityType.fromWire(r.type),
        occurredAt: r.occurredAt,
        createdAt: r.createdAt,
        description: r.description,
        photoUrl: r.photoUrl,
      );
}
