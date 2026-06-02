import 'dart:async';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/inactivity_monitor.dart';
import '../services/storage_service.dart';
import '../utils/jwt_utils.dart';
import 'database_provider.dart';

/// `flutter_secure_storage` backed by:
///  - iOS: Keychain (`first_unlock_this_device`)
///  - Android: EncryptedSharedPreferences (AES-256, forced on)
///  - macOS: Keychain
/// Web target is explicitly unsupported — `localStorage` is unencrypted
/// and would leak tokens to any JS on the same origin.
final storageServiceProvider = Provider<StorageService>((ref) {
  if (kIsWeb) {
    throw UnsupportedError(
      'AgriTrace mobile does not support the web target — tokens cannot '
      'be stored securely in browser localStorage.',
    );
  }
  return const StorageService(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});

/// Wires [ApiService] with an `onLogout` callback so the interceptor can
/// flip the auth state to [AuthUnauthenticated] when it detects an
/// unrecoverable refresh failure (i.e. the session has collapsed and the
/// router needs to bounce the user back to `/login`).
final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(
    ref.read(storageServiceProvider),
    onLogout: () {
      // The notifier may not have been built yet during very early cold-start
      // refresh failures; reading the notifier is safe — it will be created
      // lazily, and the state assignment is a no-op until the first read.
      ref.read(authProvider.notifier).markUnauthenticated();
    },
  ),
);

/// Singleton [InactivityMonitor] for the app lifetime.
///
/// v1.9.8 — P1 fix. The monitor is held in a Riverpod `Provider` (NOT
/// auto-dispose) so the same instance is shared between the root gesture
/// wrapper in `main.dart`, the `AppLifecycle` observer, and the
/// `AuthNotifier` (which arms it on login and stops it on logout).
final inactivityMonitorProvider = Provider<InactivityMonitor>((ref) {
  final monitor = InactivityMonitor();
  ref.onDispose(monitor.stop);
  return monitor;
});

/// Monotonically increasing counter incremented every time the
/// [InactivityMonitor] fires a forced logout.
///
/// v1.9.8 — P1 fix. The root [_AgriTraceAppState] in `main.dart` watches
/// this counter; a change is its cue to enqueue the "Sesión cerrada por
/// inactividad" SnackBar. A counter (vs a boolean flag) means a fast
/// back-to-back inactivity event after re-login still re-triggers the
/// listener — Riverpod only fires on value change.
final inactivityLogoutSignalProvider = StateProvider<int>((_) => 0);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.read(apiServiceProvider),
    ref.read(storageServiceProvider),
    // v1.9.3 — P0 fix. Inject a DataWiper that delegates to the shared
    // [AppDatabase]. Keeping the binding here (provider layer) means
    // [AuthService] never imports Drift and stays pure-Dart-testable.
    wipeLocalData: () =>
        ref.read(appDatabaseProvider).wipeAllUserData(),
    // v1.9.8 — P0 fix. Inject a RemotePuller that delegates to the
    // shared [SyncOrchestrator]. AuthService awaits this BEFORE the
    // notifier flips to `AuthAuthenticated`, so the dashboard rebuild
    // observes a populated Drift DB on the very first frame after
    // login/register (closes the v1.9.3 "empty dashboard after
    // logout → re-login" regression).
    pullRemoteData: () =>
        ref.read(syncOrchestratorProvider).pullAllFromServer(),
    // v1.9.9 — P0 fix (continuation of v1.9.8). Inject a PendingPusher
    // that runs the full push leg of `SyncOrchestrator.run()` so any
    // `pendingCreate`/`pendingUpdate` rows reach the server BEFORE
    // `logout()` wipes the local Drift DB. Combined with the per-mutation
    // `unawaited(syncOrchestrator.run())` hooks in the domain providers,
    // this closes the "create then logout same-second" race that left
    // the next login pulling an empty change-set.
    pushPending: () => ref.read(syncOrchestratorProvider).run(),
  ),
);

sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user, {this.pilotConsentGiven = false});
  final User user;
  /// True when the producer has accepted the Política de Privacidad
  /// (Ley 1581) on this device via [AuthNotifier.markPilotConsentGiven].
  /// The router redirects to [Routes.pilotConsent] when false.
  final bool pilotConsentGiven;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final storage = ref.read(storageServiceProvider);
    final accessToken = await storage.getAccessToken();
    if (accessToken == null) return const AuthUnauthenticated();
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) return const AuthUnauthenticated();

    // v1.9.11 — Offline-friendly cold start. Pilot farmers regularly open
    // the app at a remote plot with no coverage; the previous v1.9.10
    // behaviour ran an ACTIVE `/auth/refresh` probe here and any network
    // error would bounce the user to /login even though their tokens were
    // perfectly valid. The new two-phase flow:
    //   Phase 1 (synchronous, offline-safe): if a cached user snapshot
    //     exists AND the refresh token's JWT `exp` claim is still in the
    //     future client-side, return `AuthAuthenticated` immediately so
    //     the router goes straight to the dashboard.
    //   Phase 2 (background, async): fire `authService.refresh()` AFTER
    //     returning. 401/403 → flip to `AuthUnauthenticated` + wipe
    //     storage; network/5xx → keep the current state (the next
    //     authenticated request retries via the Dio interceptor).
    // The strict active-probe path stays intact for the case where the
    // snapshot is missing or the refresh token has already expired
    // client-side.
    //
    // v1.9.12 — Gate is the REFRESH token's `exp` (7-day TTL with rolling
    // renewal on every online refresh), NOT the access token's `exp`
    // (15 min TTL). v1.9.11 used the 15 min access-token expiry, which
    // kicked pilot producers back to the login screen at the end of a
    // long day at the plot: they had logged in at sunrise with a fresh
    // access token but by sunset the 15 min TTL had elapsed many times
    // over, even though the refresh token was still valid for days.
    // Using the refresh-token `exp` gives a full week of offline runway,
    // which matches the cadence at which producers come back to town for
    // signal.
    final snapshot = await storage.getUserSnapshot();
    if (snapshot == null || jwtIsExpired(refreshToken)) {
      return _probeAndReturn(storage);
    }

    // Arm session services synchronously — the device may already be
    // online and we want the inactivity timer running from the first frame.
    _armSessionBackgroundServices();

    final consentGiven = await storage.getPilotConsent(snapshot.email);

    // Schedule the background probe AFTER returning Authenticated so the
    // router routes the user to the dashboard with zero waiting time.
    // `Future.microtask` defers the call until the current async frame
    // resolves, which is when `build()` returns and the notifier publishes
    // the new state. `unawaited` is intentional — we want fire-and-forget.
    unawaited(Future.microtask(() => _backgroundProbe(storage)));

    return AuthAuthenticated(snapshot, pilotConsentGiven: consentGiven);
  }

  /// Legacy strict cold-start probe — the v1.9.10 behaviour. Used as the
  /// fallback when there is no cached snapshot to trust or the access
  /// token has already expired client-side. Behaviour:
  ///  - success: persists rotated tokens, seeds Drift in background, arms
  ///    session services, returns `AuthAuthenticated`.
  ///  - 401/403: refresh token rejected — delete tokens, return
  ///    `AuthUnauthenticated`.
  ///  - other DioException (5xx / network / timeout): preserve tokens,
  ///    return `AuthUnauthenticated` for this cold start; the next launch
  ///    retries.
  ///  - any other error (malformed envelope, etc.): fail closed.
  Future<AuthState> _probeAndReturn(StorageService storage) async {
    try {
      final auth = await ref.read(authServiceProvider).refresh();
      final consentGiven = await storage.getPilotConsent(auth.user.email);
      _seedInBackground('initial seed');
      _armSessionBackgroundServices();
      return AuthAuthenticated(auth.user, pilotConsentGiven: consentGiven);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await storage.deleteAll();
      }
      return const AuthUnauthenticated();
    } on StateError {
      return const AuthUnauthenticated();
    } catch (_) {
      await storage.deleteAll();
      return const AuthUnauthenticated();
    }
  }

  /// Phase 2 of the v1.9.11 cold-start. Runs AFTER [build] has already
  /// returned `AuthAuthenticated` from the cached snapshot. Three outcomes:
  ///   - success: silently rotate tokens; state stays authenticated. We
  ///     also fire a background sync so the dashboard catches up with the
  ///     server in the same session.
  ///   - 401/403: refresh token rejected by the server — flip state to
  ///     `AuthUnauthenticated`, wipe storage, stop session services.
  ///   - other DioException (network/5xx/timeout): keep current state.
  ///     The user is offline or the backend is having a moment; the next
  ///     authenticated request will retry through the Dio interceptor.
  ///
  /// Errors that are NOT [DioException] / [StateError] are logged and
  /// swallowed — a background probe must never crash the app.
  Future<void> _backgroundProbe(StorageService storage) async {
    try {
      await ref.read(authServiceProvider).refresh();
      _seedInBackground('background probe seed');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await storage.deleteAll();
        state = const AsyncData(AuthUnauthenticated());
        ref.read(inactivityMonitorProvider).stop();
        ref.read(connectivitySyncBridgeProvider).stop();
        return;
      }
      // Network / 5xx — keep the optimistic Authenticated state.
      dev.log(
        'AuthNotifier: background probe transient failure (keeping session): '
        'status=$status err=${e.type}',
        name: 'auth',
      );
    } on StateError {
      // No refresh token in storage. `build()` already guarded against
      // this, but treat defensively as a dead session.
      await storage.deleteAll();
      state = const AsyncData(AuthUnauthenticated());
    } catch (e) {
      dev.log(
        'AuthNotifier: background probe unexpected error: $e',
        name: 'auth',
      );
    }
  }

  /// Runs a sync round trip in the background, swallowing errors.
  ///
  /// Used to seed the local DB after authentication without blocking the
  /// login/cold-start flow.  Errors are logged but not surfaced.
  void _seedInBackground(String context) {
    ref.read(syncOrchestratorProvider).run().then((_) {}).catchError((Object e) {
      dev.log('AuthNotifier: $context sync failed: $e', name: 'auth');
    });
  }

  /// Flips the state to [AuthUnauthenticated] without going through
  /// [logout()] — used by the [ApiService] `onLogout` callback when the
  /// refresh interceptor detects an unrecoverable session collapse.
  void markUnauthenticated() {
    state = const AsyncData(AuthUnauthenticated());
  }

  /// Drops any [AsyncError] currently held by the notifier without changing
  /// the underlying auth status.
  ///
  /// v1.9.0 — fixes bug #4: a failed login (e.g. "Credenciales incorrectas")
  /// leaves the error banner glued to the auth state, and `LoginScreen` keeps
  /// re-rendering it even after the user has fixed their input. The screens
  /// call this from `onChanged` to wipe the banner the moment the user types
  /// in the email or password field.
  ///
  /// Idempotent: when the state is already `data` this is a no-op so the
  /// notifier never publishes a redundant frame.
  void clearError() {
    final current = state;
    if (current is! AsyncError) return;
    // Preserve the underlying value if there was one (e.g. an
    // authenticated user whose subsequent token refresh errored); fall
    // back to "unauthenticated" when none was held.
    final preserved = current.valueOrNull ?? const AuthUnauthenticated();
    state = AsyncData(preserved);
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // v1.9.8 — P0 fix. `AuthService.login` now awaits a `RemotePuller`
      // (wired in `authServiceProvider` → `SyncOrchestrator.pullAllFromServer`)
      // before returning, so the local Drift DB is hydrated by the time
      // this notifier flips to `AuthAuthenticated` and the router routes
      // the user to the dashboard. The previous fire-and-forget
      // `_seedInBackground('login seed')` raced with the first dashboard
      // render and left "No tienes fincas aún" frozen on screen until
      // the user manually pulled to refresh. Removed.
      final auth = await ref
          .read(authServiceProvider)
          .login(email: email, password: password);
      final consentGiven =
          await ref.read(storageServiceProvider).getPilotConsent(auth.user.email);
      _armSessionBackgroundServices();
      return AuthAuthenticated(auth.user, pilotConsentGiven: consentGiven);
    });
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required bool privacyConsent,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // v1.9.8 — P0 fix. Same as `login`: `AuthService.register` now
      // awaits the `RemotePuller` synchronously. New accounts start
      // with an empty server-side store so the pull returns an empty
      // change set; the call still runs for symmetry and to support
      // the rare "register against an existing account" recovery path.
      final auth = await ref.read(authServiceProvider).register(
            fullName: fullName,
            phone: phone,
            email: email,
            password: password,
            privacyConsent: privacyConsent,
          );
      final consentGiven =
          await ref.read(storageServiceProvider).getPilotConsent(auth.user.email);
      _armSessionBackgroundServices();
      return AuthAuthenticated(auth.user, pilotConsentGiven: consentGiven);
    });
  }

  Future<void> logout() async {
    // Stop the inactivity monitor BEFORE flipping the auth state so the
    // post-logout login screen never has a stale timer that could trigger
    // a second logout via [InactivityMonitor]'s callback. The same applies
    // to the timer-driven path: [_handleInactivityTimeout] re-enters this
    // method, and `stop()` here makes it idempotent.
    ref.read(inactivityMonitorProvider).stop();
    // v1.9.10 — also stop the connectivity bridge so a reconnect after
    // logout (which has just wiped Drift) does not push stale rows or
    // ping the server with an absent session.
    ref.read(connectivitySyncBridgeProvider).stop();
    // v1.10.2 fix — flip the auth state to Unauthenticated BEFORE awaiting
    // the AuthService.logout flow (which can take seconds: it pushes
    // pending changes with a 5 s timeout and posts to `/auth/logout`).
    // Doing this earlier guarantees `_AuthListenable` notifies GoRouter
    // immediately, the redirect re-evaluates the current location, and
    // the user lands on `/welcome` without having to tap something to
    // discover the session is already dead. The remaining Drift wipe +
    // server revocation continue safely in the background via the same
    // `try/finally` in `AuthService.logout`. Reported by Ana V. on
    // v1.10.1 (inactivity timeout fires, but the UI stays on the active
    // screen until the next tap triggers a 401 banner).
    state = const AsyncData(AuthUnauthenticated());
    await ref.read(authServiceProvider).logout();
  }

  /// Arms ALL session-scoped background services in one place so the
  /// three authenticated entry points (cold-start refresh, login,
  /// register) stay in lock-step.
  ///
  /// Currently: the inactivity monitor (20 min auto-logout) and the
  /// [ConnectivitySyncBridge] (auto-push on reconnect — v1.9.10).
  /// Both calls are idempotent so re-arming on every successful auth
  /// is safe.
  void _armSessionBackgroundServices() {
    _armInactivityMonitor();
    ref.read(connectivitySyncBridgeProvider).start();
  }

  /// Arms the inactivity monitor so the next 20 min of zero pointer
  /// activity force a logout. Called from cold-start refresh, login and
  /// register. Idempotent: replacing the callback is safe because the
  /// monitor cancels its existing timer in `start()`.
  void _armInactivityMonitor() {
    ref.read(inactivityMonitorProvider).start(_handleInactivityTimeout);
  }

  /// Fires when [InactivityMonitor] times out. Triggers the regular
  /// logout flow and emits a signal on [inactivityLogoutSignalProvider]
  /// so the root widget in `main.dart` can queue a SnackBar after the
  /// router routes back to `/welcome`.
  /// Records pilot-privacy consent for the current user and updates the
  /// auth state so the GoRouter redirect re-evaluates immediately.
  Future<void> markPilotConsentGiven() async {
    final current = state.valueOrNull;
    if (current is! AuthAuthenticated) return;
    await ref.read(storageServiceProvider).savePilotConsent(current.user.email);
    state = AsyncData(
      AuthAuthenticated(current.user, pilotConsentGiven: true),
    );
  }

  void _handleInactivityTimeout() {
    // Increment the signal counter BEFORE awaiting logout so the UI sees
    // the change in the same microtask as the auth state flip. Using a
    // counter (not a bool) ensures back-to-back timeouts after a fast
    // re-login still re-trigger any state listeners.
    ref.read(inactivityLogoutSignalProvider.notifier).state++;
    // Fire-and-forget — the monitor lives outside the async boundary so
    // we cannot await here. Errors are intentionally swallowed: a logout
    // network failure must not crash the lifecycle observer / gesture
    // wrapper thread.
    logout().catchError((Object e) {
      dev.log('AuthNotifier: inactivity logout failed: $e', name: 'auth');
    });
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
