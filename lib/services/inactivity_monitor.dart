import 'dart:async';

import '../utils/constants.dart';

/// Forces a logout after [kInactivityTimeoutMinutes] of no user gesture.
///
/// v1.9.8 — P1 fix. The pilot QA reported that a session left untouched
/// on a shared device stayed signed in indefinitely (the JWT access token
/// auto-refreshes silently in the background). This monitor is a pure-Dart
/// `Timer` driven by gesture pokes from a root-level `Listener` in
/// `main.dart`, and a lifecycle observer that handles app backgrounding.
///
/// Contract:
///   - `start(onTimeout)` arms the countdown. The first call is no-op if
///     already running; pass a new callback to replace the previous one.
///   - `poke()` resets the countdown — called on every pointer event.
///   - `stop()` cancels and clears the callback (call on logout).
///   - `markBackgroundedAt(DateTime)` / `resumeFromBackground(now)` model
///     the AppLifecycleState.paused → resumed transition: if more than
///     [kInactivityTimeoutMinutes] elapsed while backgrounded, the timeout
///     fires immediately on resume.
///
/// The service holds NO Flutter or Riverpod dependencies so it can be
/// unit-tested with `fake_async` (or any plain `Timer` shim). The wiring
/// into the widget tree lives in `main.dart`.
class InactivityMonitor {
  InactivityMonitor({Duration? timeout})
      : _timeout =
            timeout ?? const Duration(minutes: kInactivityTimeoutMinutes);

  final Duration _timeout;

  Timer? _timer;
  void Function()? _onTimeout;
  DateTime? _backgroundedAt;

  /// True when [start] has been called and [stop] has not since.
  bool get isRunning => _onTimeout != null;

  /// Arms the countdown.
  ///
  /// Replaces any previously-registered callback. Safe to call repeatedly
  /// (e.g. on every successful login — the monitor is a singleton).
  void start(void Function() onTimeout) {
    _onTimeout = onTimeout;
    _backgroundedAt = null;
    _resetTimer();
  }

  /// Resets the countdown back to [_timeout]. No-op when [stop] has been
  /// called (the gesture wrapper still pokes after logout while the router
  /// transitions back to the login screen).
  void poke() {
    if (_onTimeout == null) return;
    _resetTimer();
  }

  /// Cancels the countdown and clears the callback. Call on logout so a
  /// stray gesture poke or background-resume after logout cannot retrigger
  /// the logout flow on the login screen.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _onTimeout = null;
    _backgroundedAt = null;
  }

  /// Records the moment the app moved to background. Pair with
  /// [resumeFromBackground] to apply the elapsed-while-paused check.
  ///
  /// Idempotent within a single background trip: the FIRST mark wins.
  /// Flutter fires [AppLifecycleState.hidden] on BOTH the background path
  /// (`inactive → hidden → paused`) and the foreground path
  /// (`paused → hidden → inactive → resumed`). `main.dart` maps both
  /// `paused` and `hidden` to this method, so without this guard the
  /// foreground `hidden` would overwrite the real background timestamp
  /// with "now" — making the resume elapsed ≈ 0 and letting a 20 min
  /// background trip slip past the logout. `_backgroundedAt` is cleared by
  /// [resumeFromBackground], [start] and [stop], re-arming the next trip.
  void markBackgroundedAt(DateTime now) {
    if (_onTimeout == null) return;
    if (_backgroundedAt != null) return;
    _backgroundedAt = now;
    // Cancel the foreground timer — `Timer` keeps ticking while the app
    // is paused on iOS but Android may freeze it, so we do not rely on
    // it firing in the background. The resume path re-evaluates manually.
    _timer?.cancel();
    _timer = null;
  }

  /// Re-evaluates whether the inactivity timeout has elapsed while the
  /// app was in the background. Fires the callback immediately when it
  /// has, otherwise re-arms the foreground timer with the remaining
  /// budget. No-op when [markBackgroundedAt] was never called.
  void resumeFromBackground(DateTime now) {
    if (_onTimeout == null) return;
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) {
      // Resume without a paired pause (e.g. lifecycle event ordering on
      // hot restart) — restart a fresh timer to be safe.
      _resetTimer();
      return;
    }
    final elapsed = now.difference(backgroundedAt);
    if (elapsed >= _timeout) {
      // Snapshot the callback BEFORE invoking it: the callback typically
      // calls `stop()` (logout flow), which would null `_onTimeout`
      // mid-call and trip the race on slow devices.
      final cb = _onTimeout!;
      cb();
      return;
    }
    _resetTimer(remaining: _timeout - elapsed);
  }

  void _resetTimer({Duration? remaining}) {
    _timer?.cancel();
    _timer = Timer(remaining ?? _timeout, () {
      final cb = _onTimeout;
      if (cb != null) cb();
    });
  }
}
