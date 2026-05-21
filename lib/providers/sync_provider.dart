import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../widgets/common/offline_indicator.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Wires [SyncService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.read(apiServiceProvider)),
);

/// Sync state.
///
/// `null` data means "never synced this session". [SyncNotifier.trigger]
/// drains pending local changes via [SyncOrchestrator], then pulls server
/// changes.  The timestamp of the last successful sync becomes the `since`
/// cursor for the next incremental pull.
///
/// Auto-triggers on connectivity restored: a 2-second debounce avoids
/// a burst of sync calls when the network flickers.
class SyncNotifier extends AsyncNotifier<SyncResult?> {
  DateTime? _lastSyncedAt;
  Timer? _debounceTimer;

  @override
  Future<SyncResult?> build() async {
    // Watch connectivity — auto-trigger sync after a 2-second debounce when
    // the device comes back online.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final wasOnline = prev?.valueOrNull ?? false;
      final isOnline = next.valueOrNull ?? false;
      if (!wasOnline && isOnline) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 2), () {
          // Ignore errors from the background auto-sync so the notifier state
          // is not polluted; the user can always trigger manually.
          trigger().ignore();
        });
      }
    });
    ref.onDispose(() => _debounceTimer?.cancel());
    return null;
  }

  /// Triggers a full push-then-pull sync cycle via [SyncOrchestrator].
  ///
  /// The [changes] parameter is kept for backward compatibility with callers
  /// that pre-build change lists; the orchestrator also collects pending rows
  /// from the local DB automatically.
  Future<void> trigger({List<SyncChange> changes = const []}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(syncOrchestratorProvider)
          .run(since: _lastSyncedAt);
      _lastSyncedAt = result.timestamp;
      return result;
    });
  }
}

final syncProvider =
    AsyncNotifierProvider<SyncNotifier, SyncResult?>(SyncNotifier.new);
