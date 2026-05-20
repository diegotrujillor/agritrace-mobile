import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  const AuthService(this._api, this._storage);

  final ApiService _api;
  final StorageService _storage;

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
    await _storage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
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
    await _storage.saveTokens(
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    );
    return auth;
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
    return auth;
  }

  Future<void> logout() async {
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
        // best-effort server logout; always clear local tokens
      }
    }
    await _storage.deleteTokens();
  }
}
