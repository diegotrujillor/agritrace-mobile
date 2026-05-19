import 'dart:async';

import 'package:dio/dio.dart';
import '../models/user.dart';
import 'storage_service.dart';

// API_BASE_URL must be supplied at compile time via
//   --dart-define=API_BASE_URL=https://api.agritrace.co/v1
// Empty default forces a runtime assertion so a release build cannot
// silently ship without the flag. Local dev URLs (localhost / 10.0.2.2)
// are explicitly allowed; everything else must be https://.
const _baseUrl = String.fromEnvironment('API_BASE_URL');

bool _isAllowedScheme(String url) {
  if (url.startsWith('https://')) return true;
  if (url.startsWith('http://localhost')) return true;
  if (url.startsWith('http://127.0.0.1')) return true;
  if (url.startsWith('http://10.0.2.2')) return true; // Android emulator
  return false;
}

class ApiService {
  ApiService(this._storage) {
    // Runtime checks (not asserts): asserts are stripped from release builds.
    // A misconfigured release would otherwise silently ship with an empty
    // baseUrl or an insecure scheme and fail only at the first network call.
    if (_baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL must be set via --dart-define=API_BASE_URL=<https-url>',
      );
    }
    if (!_isAllowedScheme(_baseUrl)) {
      throw StateError(
        'API_BASE_URL must use HTTPS in non-local builds. Got: $_baseUrl',
      );
    }
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_dio, _storage));
  }

  final StorageService _storage;
  late final Dio _dio;

  Dio get client => _dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._storage);

  final Dio _dio;
  final StorageService _storage;

  // Completer-based lock: only one refresh request can be in flight at a
  // time. Concurrent 401s wait on the same Completer and reuse the new
  // access token without triggering a second refresh.
  Completer<String?>? _refreshLock;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Do not attempt to refresh on a /auth/refresh failure itself.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await _storage.deleteTokens();
      handler.next(err);
      return;
    }

    // If a refresh is already in flight, wait for it and reuse the result.
    if (_refreshLock != null) {
      final newToken = await _refreshLock!.future;
      if (newToken == null) {
        handler.next(err);
        return;
      }
      try {
        final retried = await _retryWithToken(err.requestOptions, newToken);
        handler.resolve(retried);
      } catch (retryErr) {
        handler.next(retryErr is DioException ? retryErr : err);
      }
      return;
    }

    final lock = Completer<String?>();
    _refreshLock = lock;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        await _storage.deleteTokens();
        lock.complete(null);
        handler.next(err);
        return;
      }
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Authorization': null}),
      );
      final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      await _storage.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );
      lock.complete(auth.accessToken);

      final retried = await _retryWithToken(err.requestOptions, auth.accessToken);
      handler.resolve(retried);
    } catch (refreshErr) {
      await _storage.deleteTokens();
      if (!lock.isCompleted) {
        lock.complete(null);
      }
      // Propagate the refresh failure rather than the original 401 so callers
      // can distinguish "wrong credentials at login" from "auth flow collapsed
      // during refresh". parseApiError can then surface the actual cause.
      handler.next(refreshErr is DioException ? refreshErr : err);
    } finally {
      _refreshLock = null;
    }
  }

  /// Builds a fresh `RequestOptions` rather than mutating the original.
  Future<Response<dynamic>> _retryWithToken(
    RequestOptions original,
    String accessToken,
  ) {
    final headers = <String, dynamic>{
      ...original.headers,
      'Authorization': 'Bearer $accessToken',
    };
    return _dio.fetch(original.copyWith(headers: headers));
  }
}
