import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/services/inactivity_monitor.dart';
import 'package:agritrace_mobile/utils/constants.dart';

void main() {
  // v1.9.8 — P1 fix. `InactivityMonitor` forces a logout after
  // [kInactivityTimeoutMinutes] (20) of no pointer activity. The tests
  // below use `fake_async` so the 20 min wait runs in microseconds.

  test('kInactivityTimeoutMinutes default is 20', () {
    expect(kInactivityTimeoutMinutes, 20);
  });

  test('fires the callback after the configured timeout elapses', () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      monitor.start(() => fires++);

      async.elapse(const Duration(minutes: 19, seconds: 59));
      expect(fires, 0, reason: 'must not fire before the timeout');

      async.elapse(const Duration(seconds: 1));
      expect(fires, 1, reason: 'must fire exactly at the timeout');
    });
  });

  test('poke() resets the timer indefinitely', () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      monitor.start(() => fires++);

      // Poke every 5 min for 25 min total — total elapsed > 20 min but
      // no 20-min gap exists between pokes.
      for (var i = 0; i < 5; i++) {
        async.elapse(const Duration(minutes: 5));
        monitor.poke();
      }

      expect(fires, 0,
          reason: 'a steady pulse must hold the timer off indefinitely');
    });
  });

  test('stop() cancels the timer and clears the callback', () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      monitor.start(() => fires++);
      async.elapse(const Duration(minutes: 10));

      monitor.stop();
      expect(monitor.isRunning, isFalse);

      async.elapse(const Duration(minutes: 30));
      expect(fires, 0, reason: 'no callback after stop()');
    });
  });

  test('start() after stop() works (re-arms cleanly)', () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      monitor.start(() => fires++);
      monitor.stop();

      // Re-arm — a producer logging back in after a forced logout must
      // get a fresh 20 min budget.
      monitor.start(() => fires++);
      async.elapse(const Duration(minutes: 20));

      expect(fires, 1);
    });
  });

  test('poke() is a no-op when the monitor was never started', () {
    final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));
    // Must not throw and must not arm a phantom timer.
    monitor.poke();
    expect(monitor.isRunning, isFalse);
  });

  test('background → resume after the full timeout fires immediately', () {
    int fires = 0;
    final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

    final start = DateTime.utc(2026, 5, 25, 9, 0);
    monitor.start(() => fires++);

    // App goes to background at 09:00, comes back 25 min later. The
    // foreground timer was cancelled at backgrounding so we must rely
    // on the resume-time elapsed check.
    monitor.markBackgroundedAt(start);
    monitor.resumeFromBackground(start.add(const Duration(minutes: 25)));

    // The callback fires synchronously inside resumeFromBackground;
    // no async elapsed is needed.
    expect(fires, 1);
  });

  test('foreground hidden does not clobber the background timestamp', () {
    // Regression: Flutter fires `hidden` on the foreground path
    // (paused → hidden → inactive → resumed). main.dart maps `hidden` to
    // markBackgroundedAt, which used to overwrite the real background
    // timestamp with ~now → resume elapsed ≈ 0 → a long background trip
    // never logged out. First mark must win.
    int fires = 0;
    final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

    final start = DateTime.utc(2026, 5, 25, 9, 0);
    monitor.start(() => fires++);

    // Real backgrounding at 09:00 (hidden then paused on the way out).
    monitor.markBackgroundedAt(start);
    monitor.markBackgroundedAt(start.add(const Duration(seconds: 1)));

    // 25 min later the foreground `hidden` fires just before `resumed`.
    final resumeAt = start.add(const Duration(minutes: 25));
    monitor.markBackgroundedAt(resumeAt); // must be ignored
    monitor.resumeFromBackground(resumeAt);

    expect(fires, 1,
        reason: 'elapsed must be measured from the first (real) mark');
  });

  test('background → resume before the timeout re-arms the remaining budget',
      () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      final start = DateTime.utc(2026, 5, 25, 9, 0);
      monitor.start(() => fires++);

      // Background at 09:00, resume 5 min later → 15 min of budget left.
      monitor.markBackgroundedAt(start);
      monitor.resumeFromBackground(start.add(const Duration(minutes: 5)));

      async.elapse(const Duration(minutes: 14, seconds: 59));
      expect(fires, 0,
          reason: 'must use the post-resume remaining budget, not a full 20');

      async.elapse(const Duration(seconds: 1));
      expect(fires, 1, reason: 'fires at the 20-min total wall-clock mark');
    });
  });

  test('resume without a paired pause re-arms a fresh full timer', () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      monitor.start(() => fires++);
      // Hot restart can deliver `resumed` without a preceding `paused` —
      // the monitor must not crash and must not fire spuriously.
      monitor.resumeFromBackground(DateTime.utc(2026, 5, 25, 9, 0));

      async.elapse(const Duration(minutes: 19, seconds: 59));
      expect(fires, 0);
      async.elapse(const Duration(seconds: 1));
      expect(fires, 1);
    });
  });

  test('background then resume → stop cleans up everything', () {
    fakeAsync((async) {
      int fires = 0;
      final monitor = InactivityMonitor(timeout: const Duration(minutes: 20));

      final start = DateTime.utc(2026, 5, 25, 9, 0);
      monitor.start(() => fires++);
      monitor.markBackgroundedAt(start);
      monitor.stop();

      // Resume after stop must be a no-op even if the resume claims a
      // huge elapsed window.
      monitor.resumeFromBackground(start.add(const Duration(hours: 5)));
      expect(fires, 0);

      async.elapse(const Duration(minutes: 30));
      expect(fires, 0);
    });
  });
}
