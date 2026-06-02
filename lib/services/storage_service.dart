import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

class StorageService {
  const StorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey  = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  // v1.9.3 — P0 fix. Persists the id of the last user that authenticated
  // on this device so the auth notifier can detect a cross-account login
  // (different user id than the cached one) and wipe the local Drift DB
  // before mounting the new session.
  static const _lastUserIdKey   = 'last_user_id';
  // v1.9.11 — Offline-friendly cold start. Persists the most recently
  // authenticated [User] alongside the tokens so [AuthNotifier.build] can
  // hand the dashboard a populated user object on the first frame even
  // when the device has no network (no `/auth/refresh` round trip).
  // Encrypted at rest by `flutter_secure_storage` (Android EncryptedSharedPreferences,
  // iOS/macOS Keychain).
  static const _userSnapshotKey = 'user_snapshot';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey,  value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken()  => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> deleteTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  /// Reads the id of the last user that authenticated on this device.
  ///
  /// v1.9.3 — companion to [saveLastUserId]. Returns `null` on a fresh
  /// install or after a previous wipe.
  Future<String?> getLastUserId() => _storage.read(key: _lastUserIdKey);

  /// Persists the id of the freshly authenticated user.
  ///
  /// Written on every successful login / register so subsequent re-logins
  /// can compare against it before tearing down the Drift DB.
  Future<void> saveLastUserId(String userId) =>
      _storage.write(key: _lastUserIdKey, value: userId);

  /// Persists a JSON-encoded snapshot of the authenticated [User].
  ///
  /// v1.9.11 — Offline-friendly cold start. `AuthNotifier.build` reads
  /// this snapshot to materialize an `AuthAuthenticated` state without a
  /// network round trip. Written on every successful login / register /
  /// cold-start refresh so the snapshot stays in lock-step with the
  /// tokens. Encrypted at rest by `flutter_secure_storage`.
  Future<void> saveUserSnapshot(User user) =>
      _storage.write(
        key: _userSnapshotKey,
        value: jsonEncode(user.toJson()),
      );

  /// Reads the persisted [User] snapshot, or `null` on a fresh install /
  /// after a wipe / on a corrupted blob.
  ///
  /// v1.9.11 — Decoding failures (older schema, hand-edited keychain,
  /// partially-written value) are swallowed so a bad snapshot can never
  /// crash the cold-start path; the auth notifier simply falls back to
  /// the strict active-refresh probe.
  Future<User?> getUserSnapshot() async {
    final raw = await _storage.read(key: _userSnapshotKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Removes the persisted snapshot.
  ///
  /// v1.9.11 — Called from [deleteAll] on logout. Exposed individually so
  /// callers that need to invalidate the snapshot without touching the
  /// tokens (none today) can do so without a race against the rest of the
  /// keychain.
  Future<void> deleteUserSnapshot() =>
      _storage.delete(key: _userSnapshotKey);

  /// Persists pilot-privacy consent acceptance for [email].
  ///
  /// Stores the ISO-8601 UTC timestamp so there is an auditable record
  /// of when the producer consented (Ley 1581). Key is per-email so
  /// multiple accounts on one device are tracked independently.
  Future<void> savePilotConsent(String email) => _storage.write(
        key: 'pilot_consent_${email.toLowerCase()}',
        value: DateTime.now().toUtc().toIso8601String(),
      );

  /// Returns true when pilot consent has already been accepted for
  /// [email] on this device.
  Future<bool> getPilotConsent(String email) async {
    final v = await _storage.read(
      key: 'pilot_consent_${email.toLowerCase()}',
    );
    return v != null && v.isNotEmpty;
  }

  /// Clears every key owned by the app (tokens + `last_user_id` +
  /// `user_snapshot`).
  ///
  /// Used by [AuthService.logout] so a logged-out device retains no
  /// trace of which account most recently used it.
  Future<void> deleteAll() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _lastUserIdKey),
      _storage.delete(key: _userSnapshotKey),
    ]);
  }
}
