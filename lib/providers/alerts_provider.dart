import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert.dart';
import '../repositories/alert_repository.dart';
import '../services/alert_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Wires [AlertService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
///
/// Still used for weather checks and as a fallback seed on first login.
final alertServiceProvider = Provider<AlertService>(
  (ref) => AlertService(ref.read(apiServiceProvider)),
);

/// Offline-first list of the producer's alerts (weather + reminders).
///
/// [build] subscribes to the reactive SQLite stream. `createReminder` writes
/// locally first; weather alerts arrive via sync pull and are applied by
/// [SyncOrchestrator.upsertFromServer]. Method names avoid shadowing
/// `AsyncNotifier` built-ins.
class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  AlertRepository get _repo => ref.read(alertRepositoryProvider);

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
  Future<List<Alert>> build() async {
    // Seed local DB from API on first build (empty DB = first login).
    final repo = _repo;
    final local = await repo.watchAll().first;
    if (local.isEmpty) {
      try {
        final remote = await ref.read(alertServiceProvider).list();
        for (final alert in remote) {
          await repo.upsertFromServer({
            ...alert.toJson(),
            'updatedAt': alert.createdAt.toIso8601String(),
          });
        }
      } catch (_) {
        // Network unavailable — continue with empty local DB.
      }
    }

    // Subscribe to reactive DB stream.
    ref.listen<AsyncValue<List<Alert>>>(
      _alertsStreamProvider,
      (_, next) => state = next,
    );

    return repo.watchAll().first;
  }

  Future<void> createReminder({
    required String title,
    required DateTime scheduledFor,
    String? body,
    String? plotId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.createReminder(
        title: title,
        scheduledFor: scheduledFor,
        body: body,
        plotId: plotId,
      );
      return _repo.watchAll().first;
    });
    if (state.hasError) return;
    _autoSyncPush('createReminder');
  }

  Future<void> dismiss(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final alerts = await _repo.watchAll().first;
      final existing = alerts.firstWhere((a) => a.id == id);
      await _repo.updateStatus(existing, AlertStatus.dismissed);
      return _repo.watchAll().first;
    });
    if (state.hasError) return;
    _autoSyncPush('dismissAlert');
  }

  Future<void> deleteAlert(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.delete(id);
      return _repo.watchAll().first;
    });
    if (state.hasError) return;
    _autoSyncPush('deleteAlert');
  }

  /// Runs the server weather check for [plotId]; applies pulled weather alert
  /// to local DB and refreshes. Returns the provider name so the UI can tell
  /// the user when weather is disabled server-side.
  Future<String> runWeatherCheck(String plotId) async {
    final result =
        await ref.read(alertServiceProvider).checkWeather(plotId);
    if (result.alert != null) {
      await _repo.upsertFromServer({
        ...result.alert!.toJson(),
        'updatedAt': result.alert!.createdAt.toIso8601String(),
      });
    }
    state = AsyncData(await _repo.watchAll().first);
    return result.provider;
  }

  /// Runs the server weather check for every plot in [plotIds] and refreshes
  /// the list once at the end. Returns the count of new weather alerts raised.
  Future<int> runWeatherCheckForAllPlots(List<String> plotIds) async {
    final service = ref.read(alertServiceProvider);
    var newAlerts = 0;
    for (final plotId in plotIds) {
      final result = await service.checkWeather(plotId);
      if (result.alert != null) {
        newAlerts++;
        await _repo.upsertFromServer({
          ...result.alert!.toJson(),
          'updatedAt': result.alert!.createdAt.toIso8601String(),
        });
      }
    }
    state = AsyncData(await _repo.watchAll().first);
    return newAlerts;
  }
}

final alertsProvider =
    AsyncNotifierProvider<AlertsNotifier, List<Alert>>(AlertsNotifier.new);

/// Internal stream provider for reactive alert updates.
final _alertsStreamProvider = StreamProvider<List<Alert>>(
  (ref) => ref.watch(alertRepositoryProvider).watchAll(),
);
