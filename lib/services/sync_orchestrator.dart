import 'dart:developer' as dev;

import '../repositories/activity_repository.dart';
import '../repositories/alert_repository.dart';
import '../repositories/farm_repository.dart';
import '../repositories/plot_repository.dart';
import 'sync_service.dart';

/// Ties the local repositories to the [SyncService] push/pull cycle.
///
/// A single [run] call:
/// 1. Collects all pending local changes from every repository.
/// 2. Pushes them to the backend via [SyncService.syncNow].
/// 3. Marks pushed rows as `'synced'`.
/// 4. Applies server-pulled rows with Last-Write-Wins semantics.
class SyncOrchestrator {
  SyncOrchestrator({
    required this.syncService,
    required this.farmRepo,
    required this.plotRepo,
    required this.activityRepo,
    required this.alertRepo,
  });

  final SyncService syncService;
  final FarmRepository farmRepo;
  final PlotRepository plotRepo;
  final ActivityRepository activityRepo;
  final AlertRepository alertRepo;

  /// Runs a full push → pull cycle.
  ///
  /// Pass [since] to request only changes after a known cursor (incremental
  /// pull); omit for a full pull (first sync after login).
  Future<SyncResult> run({DateTime? since}) async {
    final changes = await _collectPending();
    final result = await syncService.syncNow(
      changes: changes,
      since: since,
    );

    await _markSynced(changes);

    for (final change in result.pulledChanges) {
      await _applyPulledChange(change);
    }

    return result;
  }

  /// Hydrates the local Drift DB with the authenticated user's full remote
  /// state.
  ///
  /// v1.9.8 — P0 fix. Called by [AuthService] (via the `RemotePuller`
  /// callback wired in `authServiceProvider`) after every successful
  /// login/register so that:
  ///   - same-user re-login restores farms/plots/activities/alerts that
  ///     `logout()`'s `wipeAllUserData` cleared from the device, and
  ///   - any cross-device additions made since the user last opened the
  ///     app land on the dashboard immediately.
  ///
  /// Uses the existing `GET /v1/sync/changes` endpoint with no `since`
  /// cursor → the backend returns ALL rows owned by the producer (see
  /// `agritrace-backend/src/services/sync.service.ts`: `getChanges`
  /// returns every row when `since` is null). Server-pulled rows are
  /// upserted with Last-Write-Wins on `updated_at`, identical to the
  /// regular `run()` cycle. Local pending rows are NOT pushed here — that
  /// is the responsibility of the next [run] call; on a freshly wiped
  /// device there are no pending rows anyway.
  ///
  /// Throws on network/HTTP failure so the caller (AuthService) can log
  /// and decide whether to block the login flow.
  Future<void> pullAllFromServer() async {
    final result = await syncService.syncNow();
    for (final change in result.pulledChanges) {
      await _applyPulledChange(change);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<SyncChange>> _collectPending() async {
    final changes = <SyncChange>[];

    for (final row in await farmRepo.getPending()) {
      final action =
          row.syncStatus == 'pendingCreate' ? 'create' : 'update';
      changes.add(SyncChange(
        entity: 'farm',
        id: row.id,
        action: action,
        data: {
          'name': row.name,
          'cropType': row.cropType,
          'areaHectares': row.areaHectares,
          if (row.latitude != null) 'latitude': row.latitude,
          if (row.longitude != null) 'longitude': row.longitude,
          if (row.address != null) 'address': row.address,
          'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        },
      ));
    }

    for (final row in await plotRepo.getPending()) {
      final action =
          row.syncStatus == 'pendingCreate' ? 'create' : 'update';
      changes.add(SyncChange(
        entity: 'plot',
        id: row.id,
        action: action,
        data: {
          'farmId': row.farmId,
          'name': row.name,
          'cropType': row.cropType,
          'status': row.status,
          if (row.variety != null) 'variety': row.variety,
          if (row.areaHectares != null) 'areaHectares': row.areaHectares,
          'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        },
      ));
    }

    for (final row in await activityRepo.getPending()) {
      final action =
          row.syncStatus == 'pendingCreate' ? 'create' : 'update';
      changes.add(SyncChange(
        entity: 'activity',
        id: row.id,
        action: action,
        data: {
          'plotId': row.plotId,
          'type': row.type,
          'occurredAt': row.occurredAt.toUtc().toIso8601String(),
          // Always send description + photoUrl (even when null) so an
          // explicit clear ("Quitar foto" / cleared description) propagates
          // to the backend. Omitting null let the server keep the old value
          // on upsert, so a removed photo reappeared after the next pull
          // (bug #38).
          'description': row.description,
          'photoUrl': row.photoUrl,
          'quantity': row.quantity,
          'unit': row.unit,
          'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        },
      ));
    }

    for (final row in await alertRepo.getPending()) {
      final action =
          row.syncStatus == 'pendingCreate' ? 'create' : 'update';
      changes.add(SyncChange(
        entity: 'alert',
        id: row.id,
        action: action,
        data: {
          'type': row.type,
          'severity': row.severity,
          'title': row.title,
          'status': row.status,
          if (row.plotId != null) 'plotId': row.plotId,
          if (row.body != null) 'body': row.body,
          if (row.scheduledFor != null)
            'scheduledFor': row.scheduledFor!.toUtc().toIso8601String(),
          'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        },
      ));
    }

    return changes;
  }

  Future<void> _markSynced(List<SyncChange> changes) async {
    for (final c in changes) {
      switch (c.entity) {
        case 'farm':
          await farmRepo.markSynced(c.id);
        case 'plot':
          await plotRepo.markSynced(c.id);
        case 'activity':
          await activityRepo.markSynced(c.id);
        case 'alert':
          await alertRepo.markSynced(c.id);
      }
    }
  }

  Future<void> _applyPulledChange(Map<String, dynamic> change) async {
    try {
      switch (change['entity'] as String?) {
        case 'farm':
          await farmRepo.upsertFromServer(change);
        case 'plot':
          await plotRepo.upsertFromServer(change);
        case 'activity':
          await activityRepo.upsertFromServer(change);
        case 'alert':
          await alertRepo.upsertFromServer(change);
      }
    } catch (e) {
      dev.log('SyncOrchestrator: failed to apply pulled change: $e', name: 'sync');
    }
  }
}
