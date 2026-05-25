import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/activity_repository.dart';
import '../repositories/alert_repository.dart';
import '../repositories/farm_repository.dart';
import '../repositories/plot_repository.dart';
import '../services/connectivity_sync_bridge.dart';
import '../services/sync_orchestrator.dart';
import 'sync_provider.dart';

/// Single shared [AppDatabase] instance for the app lifetime.
///
/// Closed via [ref.onDispose] when the provider is removed (e.g. in tests).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Repository providers — thin wrappers that inject the shared DB instance.

final farmRepositoryProvider = Provider<FarmRepository>(
  (ref) => FarmRepository(ref.watch(appDatabaseProvider)),
);

final plotRepositoryProvider = Provider<PlotRepository>(
  (ref) => PlotRepository(ref.watch(appDatabaseProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(appDatabaseProvider)),
);

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => AlertRepository(ref.watch(appDatabaseProvider)),
);

/// [SyncOrchestrator] wired with the shared sync service + all four
/// repositories.  Consumed by [SyncNotifier] and [AuthNotifier].
final syncOrchestratorProvider = Provider<SyncOrchestrator>(
  (ref) => SyncOrchestrator(
    syncService: ref.watch(syncServiceProvider),
    farmRepo: ref.watch(farmRepositoryProvider),
    plotRepo: ref.watch(plotRepositoryProvider),
    activityRepo: ref.watch(activityRepositoryProvider),
    alertRepo: ref.watch(alertRepositoryProvider),
  ),
);

/// Singleton [ConnectivitySyncBridge] for the app lifetime.
///
/// v1.9.10 — closes the offline-mutation race: when the user mutates
/// fincas/lotes/actividades while offline, the bridge auto-fires
/// [SyncOrchestrator.run] the moment connectivity is restored, so
/// `pendingCreate`/`pendingUpdate` rows reach the server without
/// waiting for a cold-start or manual sync.
///
/// The bridge is held as a non-auto-dispose [Provider] so the same
/// instance survives across navigation rebuilds. Lifecycle (start /
/// stop) is driven by [AuthNotifier] on login / register / cold-start
/// refresh / logout.
final connectivitySyncBridgeProvider = Provider<ConnectivitySyncBridge>((ref) {
  final bridge = ConnectivitySyncBridge(
    connectivity: Connectivity(),
    onReconnected: () => ref.read(syncOrchestratorProvider).run(),
  );
  ref.onDispose(bridge.stop);
  return bridge;
});
