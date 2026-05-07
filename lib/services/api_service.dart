import 'package:dio/dio.dart';
import '../models/user.dart';
import 'storage_service.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/v1',
);

class ApiService {
  ApiService(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
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
  bool _isRefreshing = false;

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
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          await _storage.deleteTokens();
          handler.next(err);
          return;
        }
        final response = await _dio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(headers: {'Authorization': null}),
        );
        final auth = AuthResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
        await _storage.saveTokens(
          accessToken: auth.accessToken,
          refreshToken: auth.refreshToken,
        );
        final retryOptions = err.requestOptions
          ..headers['Authorization'] = 'Bearer ${auth.accessToken}';
        handler.resolve(await _dio.fetch(retryOptions));
      } catch (_) {
        await _storage.deleteTokens();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
      return;
    }
    handler.next(err);
  }
}
