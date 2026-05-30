import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../repositories/activity_repository.dart';
import '../services/activity_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Wires [ActivityService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
///
/// Still used for individual [activityProvider] lookups and as a fallback
/// seed when the local DB has no activities for the given plot.
final activityServiceProvider = Provider<ActivityService>(
  (ref) => ActivityService(ref.read(apiServiceProvider)),
);

/// Offline-first list of activities for a single plot, keyed by `plotId`.
///
/// Family-scoped so each plot detail / timeline screen has its own
/// independent state.  Mutations write to SQLite first and re-read from the
/// local DB.
///
/// Method names are deliberately `createActivity` / `updateActivity` /
/// `deleteActivity` (not `update`/`state`) so they never shadow the
/// `AsyncNotifier` built-ins.
class ActivitiesNotifier
    extends FamilyAsyncNotifier<List<Activity>, String> {
  // `arg` (the family key) is the plotId.
  String get _plotId => arg;
  ActivityRepository get _repo => ref.read(activityRepositoryProvider);

  /// v1.9.9 — see `FarmsNotifier._autoSyncPush` for the rationale.
  void _autoSyncPush(String op) {
    unawaited(
      ref.read(syncOrchestratorProvider).run().then((_) {}).catchError(
        (Object e) {
          dev.log('autoSync($op) failed: $e', name: 'sync');
        },
      ),
    );
  }

  @override
  Future<List<Activity>> build(String arg) async {
    // Seed local DB if no activities for this plot (first login / fresh
    // install).
    final repo = _repo;
    final local = await repo.listByPlot(_plotId);
    if (local.isEmpty) {
      try {
        final remote =
            await ref.read(activityServiceProvider).listByPlot(_plotId);
        for (final act in remote) {
          await repo.upsertFromServer({
            ...act.toJson(),
            'updatedAt': act.createdAt.toIso8601String(),
          });
        }
      } catch (_) {
        // Network unavailable — continue with empty local DB.
      }
    }

    // Subscribe to reactive DB stream for this plot.
    ref.listen<AsyncValue<List<Activity>>>(
      _activitiesStreamProvider(_plotId),
      (_, next) => state = next,
    );

    return _repo.listByPlot(_plotId);
  }

  Future<void> createActivity({
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.create(
        plotId: _plotId,
        type: type,
        occurredAt: occurredAt,
        description: description,
        photoUrl: photoUrl,
      );
      return _repo.listByPlot(_plotId);
    });
    if (state.hasError) return;
    _autoSyncPush('createActivity');
  }

  Future<void> updateActivity({
    required String id,
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final existing =
          (await _repo.listByPlot(_plotId)).firstWhere((a) => a.id == id);
      await _repo.update(
        existing,
        type: type,
        occurredAt: occurredAt,
        description: description,
        photoUrl: photoUrl,
      );
      return _repo.listByPlot(_plotId);
    });
    if (state.hasError) return;
    _autoSyncPush('updateActivity');
  }

  /// Returns activities for [_plotId] matching [type] that occurred on the
  /// same calendar day as [date] (compared in local time — the form's
  /// `occurredAt` is the user's picked date, which is already local).
  ///
  /// Used by the create form to surface a **soft** duplicate warning
  /// (v1.9.6): when a producer tries to log a second `Siembra` for the same
  /// lote on the same day, we ask "¿Continuar de todas formas?" rather
  /// than hard-blocking. The set of warned-on types is centralised in
  /// `kDuplicateWarnActivityTypes`.
  ///
  /// Reads the local Drift cache only — no network call. Filtering happens
  /// in Dart against [ActivityRepository.listByPlot] (the existing
  /// per-plot fetch) instead of pushing a new SQL query into the repo:
  /// the plot-scoped list is short (a few dozen rows tops for a pilot
  /// farmer) and reusing the existing path keeps the offline-first
  /// contract symmetrical with the rest of the notifier.
  Future<List<Activity>> findByPlotTypeAndDate({
    required ActivityType type,
    required DateTime date,
  }) async {
    final localDay = date.toLocal();
    final all = await _repo.listByPlot(_plotId);
    return all.where((a) {
      if (a.type != type) return false;
      final occurred = a.occurredAt.toLocal();
      return occurred.year == localDay.year &&
          occurred.month == localDay.month &&
          occurred.day == localDay.day;
    }).toList();
  }

  Future<void> deleteActivity(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.delete(id);
      return _repo.listByPlot(_plotId);
    });
    if (state.hasError) return;
    _autoSyncPush('deleteActivity');
  }
}

final activitiesProvider =
    AsyncNotifierProvider.family<ActivitiesNotifier, List<Activity>, String>(
  ActivitiesNotifier.new,
);

/// Internal stream provider keyed by plotId for reactive DB updates.
final _activitiesStreamProvider =
    StreamProvider.family<List<Activity>, String>(
  (ref, plotId) =>
      ref.watch(activityRepositoryProvider).watchByPlot(plotId),
);

/// Single activity lookup by id, used by the edit form when deep-linked.
///
/// **Local-first** (offline-first + LWW correctness — closes #34):
/// reads the row from Drift first; only falls back to the backend if
/// the activity is not in the local cache (e.g. a deep-link to an id
/// the device has never pulled). Before the local-first switch the
/// edit screen would re-show pre-edit values after a save because the
/// optimistic local mutation was already in Drift but the backend had
/// not yet received the sync push, so the next round-trip returned
/// stale data.
final activityProvider = FutureProvider.family<Activity, String>(
  (ref, id) async {
    final local = await ref.read(activityRepositoryProvider).getById(id);
    if (local != null) return local;
    return ref.read(activityServiceProvider).get(id);
  },
);
