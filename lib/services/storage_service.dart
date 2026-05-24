import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Clears every key owned by the app (tokens + `last_user_id`).
  ///
  /// Used by [AuthService.logout] so a logged-out device retains no
  /// trace of which account most recently used it.
  Future<void> deleteAll() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _lastUserIdKey),
    ]);
  }
}
