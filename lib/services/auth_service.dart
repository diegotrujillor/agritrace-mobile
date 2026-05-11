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
  }) async {
    // `role` is intentionally NOT sent — the server assigns it based on
    // the endpoint (public /auth/register always yields 'producer').
    // Sending a client-chosen role would be an authz bypass attempt.
    final response = await _api.client.post('/auth/register', data: {
      'fullName': fullName,
      'phone': phone,
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
