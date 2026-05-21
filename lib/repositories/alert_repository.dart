import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/alert.dart';

/// Local-first repository for [Alert] entities.
///
/// Alerts are primarily server-pushed (weather events).  Client-side creates
/// are limited to `reminder` type.  Status updates (dismiss) are written
/// locally as [pendingUpdate] and synced to the backend later.
///
/// All enum columns are stored as their wire string (`.name`) and restored via
/// `fromWire` on read.
class AlertRepository {
  AlertRepository(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Reactive stream of all alerts, newest first.
  Stream<List<Alert>> watchAll() =>
      _db.watchAlerts().map((rows) => rows.map(_fromRow).toList());

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a reminder alert locally and marks it [pendingCreate] for sync.
  Future<Alert> createReminder({
    required String title,
    required DateTime scheduledFor,
    String? body,
    String? plotId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db.upsertAlert(AlertsTableCompanion(
      id: Value(id),
      type: const Value('reminder'),
      severity: const Value('info'),
      title: Value(title),
      status: const Value('pending'),
      plotId: Value(plotId),
      body: Value(body),
      scheduledFor: Value(scheduledFor.toUtc()),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pendingCreate'),
    ));
    return Alert(
      id: id,
      type: AlertType.reminder,
      severity: AlertSeverity.info,
      title: title,
      status: AlertStatus.pending,
      createdAt: now,
      plotId: plotId,
      body: body,
      scheduledFor: scheduledFor,
    );
  }

  /// Updates alert status locally (e.g. dismiss) and marks it [pendingUpdate].
  Future<Alert> updateStatus(Alert existing, AlertStatus status) async {
    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(status: status);
    await _db.upsertAlert(AlertsTableCompanion(
      id: Value(existing.id),
      type: Value(existing.type.wire),
      severity: Value(existing.severity.wire),
      title: Value(existing.title),
      status: Value(status.wire),
      plotId: Value(existing.plotId),
      body: Value(existing.body),
      scheduledFor: Value(existing.scheduledFor),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(now),
      syncStatus: const Value('pendingUpdate'),
    ));
    return updated;
  }

  /// Deletes an alert from the local DB immediately.
  Future<void> delete(String id) => _db.deleteAlertById(id);

  // ── Sync helpers ──────────────────────────────────────────────────────────

  /// Returns all rows whose [syncStatus] is not `'synced'`.
  Future<List<AlertsTableData>> getPending() => _db.getPendingAlerts();

  /// Marks a row as `'synced'` after the backend accepted the change.
  Future<void> markSynced(String id) => _db.markAlertSynced(id);

  /// Upserts a row received from the server pull leg (LWW — server wins).
  Future<void> upsertFromServer(Map<String, dynamic> data) async {
    final row = Alert.fromJson(data);
    final updatedAt = data['updatedAt'] != null
        ? DateTime.parse(data['updatedAt'] as String)
        : row.createdAt;
    await _db.upsertAlert(AlertsTableCompanion(
      id: Value(row.id),
      type: Value(row.type.wire),
      severity: Value(row.severity.wire),
      title: Value(row.title),
      status: Value(row.status.wire),
      plotId: Value(row.plotId),
      body: Value(row.body),
      scheduledFor: Value(row.scheduledFor),
      createdAt: Value(row.createdAt),
      updatedAt: Value(updatedAt),
      syncStatus: const Value('synced'),
    ));
  }

  // ── Mapper ────────────────────────────────────────────────────────────────

  static Alert _fromRow(AlertsTableData r) => Alert(
        id: r.id,
        type: AlertType.fromWire(r.type),
        severity: AlertSeverity.fromWire(r.severity),
        title: r.title,
        status: AlertStatus.fromWire(r.status),
        createdAt: r.createdAt,
        plotId: r.plotId,
        body: r.body,
        scheduledFor: r.scheduledFor,
      );
}
