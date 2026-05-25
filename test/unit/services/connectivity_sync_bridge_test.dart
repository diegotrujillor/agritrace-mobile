import 'dart:async';

import 'package:agritrace_mobile/services/connectivity_sync_bridge.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// v1.9.10 — `ConnectivitySyncBridge` fires `onReconnected` on every
// offline → online transition. These tests pin the transition logic
// using a fake `Connectivity` driven by a `StreamController`.

class _MockConnectivity extends Mock implements Connectivity {}

/// Test harness that wires a [_MockConnectivity] to a controllable
/// stream + an initial [checkConnectivity] value, and counts how many
/// times the reconnect callback fires.
class _Harness {
  _Harness({required List<ConnectivityResult> initial}) {
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => controller.stream);
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => initial);
  }

  final _MockConnectivity connectivity = _MockConnectivity();
  final StreamController<List<ConnectivityResult>> controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  int fires = 0;

  ConnectivitySyncBridge build() => ConnectivitySyncBridge(
        connectivity: connectivity,
        onReconnected: () async => fires++,
      );

  Future<void> emit(List<ConnectivityResult> r) async {
    controller.add(r);
    // Drain microtasks so the listener's _handle runs before assertion.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> dispose() async {
    await controller.close();
  }
}

const _online = <ConnectivityResult>[ConnectivityResult.wifi];
const _offline = <ConnectivityResult>[ConnectivityResult.none];

void main() {
  test('offline then online fires onReconnected exactly once', () async {
    final h = _Harness(initial: _offline);
    addTearDown(h.dispose);
    final bridge = h.build();

    bridge.start();
    // Let the seeded `checkConnectivity()` resolve so `_wasOffline` is true.
    await Future<void>.delayed(Duration.zero);
    expect(h.fires, 0, reason: 'must not fire on the seeded offline state');

    await h.emit(_online);
    expect(h.fires, 1, reason: 'must fire on the offline → online edge');
  });

  test('online → offline → online fires once', () async {
    final h = _Harness(initial: _online);
    addTearDown(h.dispose);
    final bridge = h.build();

    bridge.start();
    await Future<void>.delayed(Duration.zero);
    expect(h.fires, 0, reason: 'seeded online state must not fire');

    await h.emit(_offline);
    expect(h.fires, 0, reason: 'going offline must not fire');

    await h.emit(_online);
    expect(h.fires, 1, reason: 'reconnect after going offline must fire');
  });

  test('always online from boot never fires', () async {
    final h = _Harness(initial: _online);
    addTearDown(h.dispose);
    final bridge = h.build();

    bridge.start();
    await Future<void>.delayed(Duration.zero);
    await h.emit(_online);
    await h.emit(_online);
    expect(h.fires, 0,
        reason:
            'with no offline transition there is nothing to reconnect from');
  });

  test('offline from boot then online fires once', () async {
    final h = _Harness(initial: _offline);
    addTearDown(h.dispose);
    final bridge = h.build();

    bridge.start();
    await Future<void>.delayed(Duration.zero);
    await h.emit(_online);
    expect(h.fires, 1);
  });

  test('start() is idempotent — second call does not duplicate listener',
      () async {
    final h = _Harness(initial: _offline);
    addTearDown(h.dispose);
    final bridge = h.build();

    bridge.start();
    bridge.start(); // second call: no-op
    await Future<void>.delayed(Duration.zero);
    await h.emit(_online);
    // If start() had double-subscribed, fires would be 2.
    expect(h.fires, 1);
    // Surface the fact that onConnectivityChanged was only resolved once.
    verify(() => h.connectivity.onConnectivityChanged).called(1);
  });

  test('stop() cancels and a subsequent start() works again', () async {
    final h = _Harness(initial: _offline);
    addTearDown(h.dispose);
    final bridge = h.build();

    bridge.start();
    await Future<void>.delayed(Duration.zero);
    bridge.stop();
    expect(bridge.isRunning, isFalse);

    // Re-seed: emit while stopped must NOT fire.
    await h.emit(_online);
    expect(h.fires, 0,
        reason: 'events emitted while stopped must be ignored');

    // Restart and verify a fresh offline → online edge still fires.
    bridge.start();
    await Future<void>.delayed(Duration.zero);
    await h.emit(_offline);
    await h.emit(_online);
    expect(h.fires, 1);
  });

  test('reconnect callback throwing does not poison the subscription',
      () async {
    final h = _Harness(initial: _offline);
    addTearDown(h.dispose);
    var fires = 0;
    final bridge = ConnectivitySyncBridge(
      connectivity: h.connectivity,
      onReconnected: () async {
        fires++;
        throw StateError('boom');
      },
    );

    bridge.start();
    await Future<void>.delayed(Duration.zero);
    await h.emit(_online);
    // _handle swallows the error — second transition should still fire.
    await h.emit(_offline);
    await h.emit(_online);
    // Let any pending microtasks settle.
    await Future<void>.delayed(Duration.zero);
    expect(fires, 2);
  });
}
