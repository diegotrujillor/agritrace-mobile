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
  const AuthService(
    this._api,
    this._storage, {
    DataWiper? wipeLocalData,
    RemotePuller? pullRemoteData,
  })  : _wipeLocalData = wipeLocalData,
        _pullRemoteData = pullRemoteData;

  final ApiService _api;
  final StorageService _storage;
  final DataWiper? _wipeLocalData;
  final RemotePuller? _pullRemoteData;

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
    // v1.9.3 — P0 fix (defense in depth). A brand-new account on a device
    // that previously hosted another account must not inherit its rows.
    await _wipeIfCrossUser(auth.user.id);
    await _storage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    await _storage.saveLastUserId(auth.user.id);
    // v1.9.8 — P0 fix. Hydrate the local Drift DB from the server before
    // returning. A fresh account starts empty server-side so this is a
    // no-op for the happy path, but keeping the call here mirrors the
    // login flow (and protects the rare case where a producer registers
    // again to recover a session against an existing account).
    await _hydrateFromRemote();
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
    // v1.9.3 — P0 fix (defense in depth). The user may close the app
    // without ever calling `logout()`; if someone else then logs in on
    // the same device they would otherwise see the previous account's
    // farms, plots, activities and alerts. Wipe whenever the freshly
    // authenticated id differs from the one cached at the last login.
    await _wipeIfCrossUser(auth.user.id);
    await _storage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    await _storage.saveLastUserId(auth.user.id);
    // v1.9.8 — P0 fix. Pull the authenticated user's farms/plots/activities/
    // alerts from the server INTO the local Drift DB before returning so the
    // dashboard (which reads local-first) sees a populated state on the
    // very first frame after login. Required because logout wipes Drift —
    // without this hydration step a same-user re-login renders "No tienes
    // fincas aún" indefinitely until the user manually triggers a sync.
    await _hydrateFromRemote();
    return auth;
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
    return auth;
  }

  Future<void> logout() async {
    try {
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
}
