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
    final response = await _api.client.post('/auth/register', data: {
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'password': password,
      'role': 'producer',
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
    try {
      await _api.client.post('/auth/logout');
    } catch (_) {
      // best-effort server logout; always clear local tokens
    } finally {
      await _storage.deleteTokens();
    }
  }
}
