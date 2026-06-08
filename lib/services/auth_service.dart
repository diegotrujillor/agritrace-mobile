import 'dart:developer' as dev;

import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Callback invoked when the auth flow needs to truncate the local Drift
/// database (cross-account login or logout).
///
/// v1.9.3 — injected via constructor so [AuthService] stays free of any
/// Drift / Flutter imports and remains pure-Dart-testable. The provider
/// layer (`lib/providers/auth_provider.dart`) wires it to
/// `AppDatabase.wipeAllUserData`.
typedef DataWiper = Future<void> Function();

/// Callback invoked after a successful login/register to hydrate the local
/// Drift DB with the authenticated user's remote state.
///
/// v1.9.8 — P0 fix. After v1.9.3 wipe-on-logout, a same-user re-login left
/// the dashboard empty because nothing pulled remote state back. The
/// `RemotePuller` is awaited as part of the login/register flow so the
/// dashboard rebuild sees a populated DB. Errors must NOT propagate — the
/// caller logs and continues so an offline login still completes.
typedef RemotePuller = Future<void> Function();

/// Callback invoked BEFORE [AuthService.logout] wipes the local Drift DB,
/// to give the orchestrator one last chance to flush pending local rows
/// to the server.
///
/// v1.9.9 — P0 continuation. v1.9.8 fixed the same-user re-login empty
/// dashboard by pulling on login, but the symmetric hole on the push side
/// remained: a `pendingCreate` row created in the session was destroyed by
/// `wipeAllUserData` BEFORE ever reaching the server, so the next login
/// pulled an empty change-set. Combined with the auto-push hooks in every
/// provider mutation, this final push is defense in depth for the
/// "create then logout immediately" race.
///
/// The pusher is fire-and-forget WITH A TIMEOUT — a slow or offline
/// backend must NOT block logout. The privacy invariant (next user must
/// not see the previous user's rows) ALWAYS wins over the convenience
/// invariant (preserve unsynced changes).
typedef PendingPusher = Future<void> Function();

class AuthService {
  /// [wipeLocalData] is `null`-safe: when omitted (e.g. in legacy tests
  /// that only exercise the network surface) the wipe step is silently
  /// skipped. Production callers always supply it through
  /// `authServiceProvider`.
  ///
  /// [pullRemoteData] is `null`-safe too. When supplied, it is called
  /// AWAITED after every successful login/register so the local Drift DB
  /// is hydrated before the auth state flips to authenticated. Errors are
  /// caught and logged — an offline login still completes and the user can
  /// create local data while the pull retries later.
  ///
  /// [pushPending] is `null`-safe too. v1.9.9. When supplied, [logout]
  /// awaits ONE final push (capped by a 5 s timeout) BEFORE wiping the
  /// local Drift DB and clearing secure storage. Failures are logged and
  /// swallowed — the wipe always runs.
  const AuthService(
    this._api,
    this._storage, {
    DataWiper? wipeLocalData,
    RemotePuller? pullRemoteData,
    PendingPusher? pushPending,
  })  : _wipeLocalData = wipeLocalData,
        _pullRemoteData = pullRemoteData,
        _pushPending = pushPending;

  final ApiService _api;
  final StorageService _storage;
  final DataWiper? _wipeLocalData;
  final RemotePuller? _pullRemoteData;
  final PendingPusher? _pushPending;

  /// Hard ceiling on the final push performed by [logout]. A slow or
  /// offline backend must NOT keep the user staring at a spinner while
  /// they wait to log out; 5 s matches the existing Dio default connect
  /// timeout and is comfortably long enough on a healthy LTE link.
  static const Duration _logoutPushTimeout = Duration(seconds: 5);

  Future<AuthResponse> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required bool privacyConsent,
    String privacyConsentVersion = '1.0',
  }) async {
    // `role` is intentionally NOT sent — the server assigns it based on
    // the endpoint (public /auth/register always yields 'producer').
    // Sending a client-chosen role would be an authz bypass attempt.
    final response = await _api.client.post('/auth/register', data: {
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'password': password,
      'privacyConsent': privacyConsent,
      'privacyConsentVersion': privacyConsentVersion,
    });
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistSession(auth, 'register');
    return auth;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.client.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _persistSession(auth, 'login');
    return auth;
  }

  /// Persists the authenticated session and runs best-effort local setup.
  ///
  /// By the time this runs the network auth has already succeeded, so the
  /// user IS authenticated. Only the token write is essential; everything
  /// after it is LOCAL bookkeeping (cross-user Drift wipe, user snapshot,
  /// remote hydration) and is wrapped so a local/storage/Drift failure can
  /// NEVER strand an authenticated user on the catch-all "Ocurrió un error".
  ///
  /// That was the v1.11.x stale-state login bug: when an account is
  /// recreated (purge + re-register → new `user.id`), login hit the
  /// cross-user branch over stale local state and threw; the opaque
  /// `parseApiError` fallthrough hid the real cause and the only workaround
  /// was "Clear app data" — unusable for a pilot farmer. Now the wipe /
  /// snapshot steps self-heal: the real exception is logged (visible in
  /// `adb logcat`, tag `auth`) and the session still completes.
  Future<void> _persistSession(AuthResponse auth, String flow) async {
    // Essential: without tokens the session is useless. A failure here is a
    // genuine storage fault and is allowed to propagate.
    await _storage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    // v1.9.3 — P0 cross-user wipe. MUST run BEFORE the marker is updated
    // below (it compares the PREVIOUS `last_user_id`). Best-effort: a
    // Drift failure must not abort an already-authenticated session.
    await _runLocalStep(
      () => _wipeIfCrossUser(auth.user.id),
      'cross-user wipe',
      flow,
    );
    await _storage.saveLastUserId(auth.user.id);
    // v1.9.11 — snapshot powers the offline cold-start path. Best-effort.
    await _runLocalStep(
      () => _storage.saveUserSnapshot(auth.user),
      'user snapshot',
      flow,
    );
    // v1.9.8 — hydrate Drift from the server (already swallows its errors).
    await _hydrateFromRemote();
  }

  /// Runs a non-critical local-setup [step], swallowing and LOGGING any
  /// failure. The session is already authenticated, so a local hiccup must
  /// not surface as an auth error. The log carries the real exception +
  /// stack so the (otherwise invisible) root cause is recoverable from
  /// `adb logcat`.
  Future<void> _runLocalStep(
    Future<void> Function() step,
    String label,
    String flow,
  ) async {
    try {
      await step();
    } catch (e, st) {
      dev.log(
        'AuthService: $label failed on $flow (session preserved): $e',
        name: 'auth',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Awaits the injected [RemotePuller] when present and swallows any
  /// error. Logging is intentional — a producer logging in on a flaky
  /// connection must still reach the dashboard (where they can keep
  /// creating local-only rows; the next online sync will push them).
  ///
  /// No-op when the host did not supply a puller (legacy unit-test
  /// constructions of `AuthService` that don't exercise sync).
  Future<void> _hydrateFromRemote() async {
    final puller = _pullRemoteData;
    if (puller == null) return;
    try {
      await puller();
    } catch (e) {
      dev.log(
        'AuthService: remote hydration failed on login/register: $e',
        name: 'auth',
      );
    }
  }

  /// Wipes the local Drift DB iff the cached `last_user_id` is set AND
  /// differs from [newUserId]. The first login on a device leaves the
  /// DB untouched — there is no previous account whose data could leak.
  ///
  /// No-op when the host did not supply a [DataWiper] (legacy unit-test
  /// constructions of `AuthService`).
  Future<void> _wipeIfCrossUser(String newUserId) async {
    final wiper = _wipeLocalData;
    if (wiper == null) return;
    final lastUserId = await _storage.getLastUserId();
    if (lastUserId != null && lastUserId != newUserId) {
      await wiper();
    }
  }

  /// Probes the backend with the stored refresh token. Returns the renewed
  /// [AuthResponse] on success and persists the rotated tokens. Used by
  /// [AuthNotifier.build] on cold start as an ACTIVE session probe — the
  /// previous client-only `exp` heuristic could not detect server-side
  /// rotation/revocation of the JWT secret or device clock skew, leading
  /// to "zombie" sessions that crashed at the first API call.
  ///
  /// Throws `StateError` when no refresh token is stored. Propagates the
  /// underlying [DioException] on network/HTTP failure so callers can
  /// distinguish a real refresh failure from a missing-token state.
  Future<AuthResponse> refresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('no refresh token in storage');
    }
    final response = await _api.client.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
    await _storage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    // v1.9.3 — keep the cached `last_user_id` in sync on cold-start
    // refresh too. The probe is the first place the freshly-bound app
    // learns who the active session belongs to; without this, a device
    // that re-installs the app (tokens still in Keychain after Android
    // backup-restore) would never seed the marker and the cross-account
    // check on the next login could miss.
    await _storage.saveLastUserId(auth.user.id);
    // v1.9.11 — refresh also rotates the persisted user snapshot. The
    // payload rarely changes (id/email/role are stable across token
    // rotations) but writing on every refresh keeps the snapshot in
    // sync if the backend ever updates `fullName` / `phone` server-side.
    await _storage.saveUserSnapshot(auth.user);
    return auth;
  }

  Future<void> logout() async {
    try {
      // v1.9.9 — P0 fix (continuation of v1.9.8). Push any local pending
      // changes BEFORE wiping the Drift DB. Without this, a farm/plot/
      // activity/alert created in the same session that has not yet been
      // auto-synced (e.g. created offline; created online then logged out
      // within the same second) would be destroyed by the `wipeLocalData`
      // call below, and the next login's `pullAllFromServer` would return
      // an empty change-set — the dashboard renders "No tienes fincas
      // aún" again, even though the user "saw" them right up to logout.
      //
      // Fire-and-forget with a hard 5 s timeout: a slow or offline backend
      // must NOT block logout. If the push fails or times out, the wipe
      // still runs because the privacy invariant (next user must not see
      // the previous user's rows) ALWAYS wins over the convenience
      // invariant (preserve unsynced changes). Combined with the
      // auto-push hooks added to every provider mutation in v1.9.9, this
      // is defense in depth for the residual "mutate then logout same
      // second" race.
      await _pushPendingBeforeLogout();

      final refreshToken = await _storage.getRefreshToken();
      // Skip the network call entirely when there is nothing to revoke
      // server-side; this keeps the request log clean and matches the
      // backend's `logoutSchema` which requires a non-empty refreshToken.
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await _api.client.post(
            '/auth/logout',
            data: {'refreshToken': refreshToken},
          );
        } catch (_) {
          // best-effort server logout; always clear local state below.
        }
      }
    } finally {
      // v1.9.3 — P0 fix. Logout MUST always:
      //   1. clear tokens + `last_user_id` from secure storage, and
      //   2. wipe the local Drift DB so the next user that logs in on
      //      this device cannot see the previous account's data.
      // Wrapping the clears in `finally` guarantees they run even if
      // reading the refresh token or the server round-trip throws an
      // unexpected exception above (the inner `try` only swallows the
      // `_api.client.post` failure).
      await _storage.deleteAll();
      final wiper = _wipeLocalData;
      if (wiper != null) await wiper();
    }
  }

  /// Awaits the injected [PendingPusher] (when present) with a hard
  /// [_logoutPushTimeout]. Always returns; errors and timeouts are logged
  /// and swallowed so the wipe step in [logout] cannot be skipped.
  ///
  /// No-op when no pusher is wired (legacy unit-test constructions of
  /// `AuthService`).
  Future<void> _pushPendingBeforeLogout() async {
    final pusher = _pushPending;
    if (pusher == null) return;
    try {
      await pusher().timeout(_logoutPushTimeout);
    } catch (e) {
      dev.log(
        'AuthService: final push before logout failed (wiping anyway): $e',
        name: 'auth',
      );
    }
  }
}
