import 'dart:async';
import 'dart:developer' as dev;

import 'package:connectivity_plus/connectivity_plus.dart';

/// Listens to network transitions and triggers a sync push the moment the
/// device regains connectivity.
///
/// v1.9.10 — closes the offline-mutation race exposed in pilot QA cycle-2:
/// a producer creating fincas/lotes/actividades while offline left those
/// rows as `pendingCreate` until the next cold-start or manual sync. With
/// this bridge active, the same rows reach the server within seconds of
/// reconnect without any user gesture.
///
/// The bridge is intentionally a plain service (no Flutter widget tree
/// dependency) so it can be unit-tested with a fake [Connectivity] and a
/// `StreamController<List<ConnectivityResult>>`.
class ConnectivitySyncBridge {
  ConnectivitySyncBridge({
    required this.connectivity,
    required this.onReconnected,
  });

  final Connectivity connectivity;

  /// Invoked on every offline → online transition. The callback is
  /// expected to be non-throwing; any error is caught and logged so a
  /// flaky sync round-trip cannot poison the stream subscription.
  final Future<void> Function() onReconnected;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOffline = false;

  /// True when [start] has been called and [stop] has not since.
  bool get isRunning => _sub != null;

  /// Subscribes to [Connectivity.onConnectivityChanged] and seeds the
  /// initial state via [Connectivity.checkConnectivity]. Idempotent — a
  /// second call while already running is a no-op (the existing
  /// subscription is reused).
  void start() {
    if (_sub != null) return;
    _sub = connectivity.onConnectivityChanged.listen(_handle);
    // Seed initial state so an app that starts already online does not
    // misfire on the first event. The future is intentionally not awaited
    // — `start()` must remain synchronous so the caller (auth_provider)
    // can chain it with other arming logic without `await`.
    connectivity.checkConnectivity().then(_handle).catchError((Object e) {
      dev.log('connectivity probe failed: $e', name: 'sync');
    });
  }

  /// Cancels the subscription and resets internal state so the next
  /// [start] begins from a clean slate. Call on logout so a stale
  /// reconnect after the local DB has been wiped cannot trigger a sync
  /// against the new (or absent) session.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _wasOffline = false;
  }

  /// Maps a connectivity event to either a reconnect callback fire or a
  /// "now offline" state update. The transition logic is the single
  /// authoritative gate: we only fire when we were previously offline
  /// AND we are currently online.
  void _handle(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (_wasOffline && isOnline) {
      _wasOffline = false;
      onReconnected().catchError((Object e) {
        dev.log('reconnect sync failed: $e', name: 'sync');
      });
    } else if (!isOnline) {
      _wasOffline = true;
    }
  }
}
