import 'dart:async';

import 'package:dio/dio.dart';
// `meta` ships transitively with the Flutter SDK; the lint asks us to
// declare it explicitly only if `pubspec.yaml` adds it as a direct dep.
// We skip the dependency and the annotation to keep `pubspec.yaml` clean
// — `_buildAuthInterceptorForTest` is exported via library-private naming.
import '../models/user.dart';
import 'storage_service.dart';

// API_BASE_URL must be supplied at compile time via
//   --dart-define=API_BASE_URL=https://api.agritrace.co/v1
// Empty default forces a runtime assertion so a release build cannot
// silently ship without the flag. Local dev URLs (localhost / 10.0.2.2)
// are explicitly allowed; everything else must be https://.
const _baseUrl = String.fromEnvironment('API_BASE_URL');

/// Path on the backend for the refresh-token endpoint. Centralised so the
/// interceptor and the request-skip check stay in sync.
const String kAuthRefreshPath = '/auth/refresh';

/// Path on the backend for the login endpoint. The interceptor must NOT
/// attempt a refresh when this path returns 401 — a fresh login with
/// wrong credentials should surface as "Credenciales incorrectas", never
/// as the session-expired collapse sentinel (bug #7).
const String kAuthLoginPath = '/auth/login';

/// Path on the backend for the register endpoint. Same skip-reasoning as
/// [kAuthLoginPath] — a 401 here (anonymous, no token sent) is not a
/// session-expired event.
const String kAuthRegisterPath = '/auth/register';

bool _isAllowedScheme(String url) {
  if (url.startsWith('https://')) return true;
  if (url.startsWith('http://localhost')) return true;
  if (url.startsWith('http://127.0.0.1')) return true;
  if (url.startsWith('http://10.0.2.2')) return true; // Android emulator
  return false;
}

/// Sentinel emitted via [DioException.error] when the refresh flow has
/// collapsed (refresh token rejected with 401/403, or storage of the
/// renewed tokens failed). Lets [parseApiError] distinguish "wrong
/// credentials at login" from "the session expired mid-flight".
final class AuthSessionCollapsed {
  const AuthSessionCollapsed();
}

/// Extra-key set on the rejected [RequestOptions] when the failure was
/// produced by [_AuthInterceptor] after detecting an unrecoverable refresh
/// failure. Read by [parseApiError] as a second detection channel.
const String kAuthFlowCollapsedExtra = 'authFlowCollapsed';

class ApiService {
  ApiService(this._storage, {void Function()? onLogout}) : _onLogout = onLogout {
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
    final baseOptions = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    );
    _dio = Dio(baseOptions);
    // Dedicated client for /auth/refresh with NO interceptors → no recursion
    // and no chance of attaching the expired Bearer token to the refresh call.
    _refreshDio = Dio(baseOptions);
    final interceptor = _AuthInterceptor(
      storage: _storage,
      refreshClient: _refreshDio,
      onLogout: _onLogout,
    );
    interceptor._dioForRetry = _dio;
    _dio.interceptors.add(interceptor);
  }

  final StorageService _storage;
  final void Function()? _onLogout;
  late final Dio _dio;
  late final Dio _refreshDio;

  Dio get client => _dio;
}

/// Marker exception used internally to signal that the refresh flow has
/// collapsed in an unrecoverable way (refresh token rejected by the server,
/// missing tokens, or persistence failure). Transient failures (5xx,
/// network, timeout) are rethrown instead so the original 401 can pass
/// through unchanged.
class _RefreshFailure implements Exception {
  const _RefreshFailure(this.reason);
  final String reason;
  @override
  String toString() => '_RefreshFailure($reason)';
}

/// Test-only factory for wiring an [_AuthInterceptor] into an externally
/// owned [Dio]. Returns the interceptor so tests can drive its lifecycle
/// without going through [ApiService] (which requires `API_BASE_URL` at
/// compile-time). NOTE: kept top-level intentionally for tests; the name
/// communicates intent (no `@visibleForTesting` annotation to avoid pulling
/// in `package:meta` as a direct dep).
QueuedInterceptor buildAuthInterceptorForTest({
  required Dio dio,
  required Dio refreshClient,
  required StorageService storage,
  void Function()? onLogout,
}) {
  final interceptor = _AuthInterceptor(
    storage: storage,
    refreshClient: refreshClient,
    onLogout: onLogout,
  );
  interceptor._dioForRetry = dio;
  dio.interceptors.add(interceptor);
  return interceptor;
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor({
    required StorageService storage,
    required Dio refreshClient,
    void Function()? onLogout,
  })  : _storage = storage,
        _refreshClient = refreshClient,
        _onLogout = onLogout;

  final StorageService _storage;
  final Dio _refreshClient;
  final void Function()? _onLogout;

  /// The Dio instance whose interceptor chain THIS interceptor lives in.
  /// Used for replaying the original request after a successful refresh.
  /// Assigned by [ApiService] right after `interceptors.add(...)`.
  late final Dio _dioForRetry;

  /// Single-flight cache for the in-flight refresh. Concurrent 401s share
  /// the same future and all retry against the new token, so only ONE
  /// `/auth/refresh` ever hits the network at a time.
  Future<String>? _refreshFuture;

  /// Per-request stash of the access token used on the originating attempt.
  /// Read on the retry to short-circuit the refresh when another request
  /// has already rotated the token.
  static const String _kReqToken = '_auth_req_token';

  /// Per-request retry budget. Capped at 1 to prevent infinite refresh loops
  /// when the renewed token is itself rejected.
  static const String _kAttempts = '_auth_attempts';

  /// Max number of refresh-driven retries per originating request.
  static const int _maxAttempts = 1;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Never attach a Bearer header to the refresh endpoint itself; the
    // refresh route is auth'd by the refresh token in the body.
    if (_isRefreshPath(options.path)) {
      handler.next(options);
      return;
    }
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_kReqToken] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isAuthError = err.response?.statusCode == 401;
    // Three early-outs share the same shape:
    //  - not a 401 → not our concern
    //  - 401 on the refresh path → already handled inside _doRefresh
    //  - 401 on login/register (anonymous, no Bearer to refresh) →
    //    surfacing this as a "session expired" sentinel was bug #7 in
    //    the v1.9.0 backlog. Pass through verbatim so `parseApiError`
    //    can render "Credenciales incorrectas" instead.
    if (!isAuthError ||
        _isRefreshPath(err.requestOptions.path) ||
        _isAnonymousAuthPath(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    // Retry budget — never refresh more than once for the same originating
    // request. If the retry also 401s, surface that 401 verbatim.
    final attempts = (err.requestOptions.extra[_kAttempts] as int?) ?? 0;
    if (attempts >= _maxAttempts) {
      handler.next(err);
      return;
    }

    // Another concurrent request may have already refreshed the token.
    // Detect by comparing the token that travelled WITH this request to
    // the token currently in storage — if they differ, just retry without
    // firing another refresh.
    final originalReqToken = err.requestOptions.extra[_kReqToken] as String?;
    final storedToken = await _storage.getAccessToken();
    if (storedToken != null &&
        originalReqToken != null &&
        storedToken != originalReqToken) {
      await _retryAndResolve(
        original: err.requestOptions,
        accessToken: storedToken,
        attempts: attempts,
        handler: handler,
        originalErr: err,
      );
      return;
    }

    final String newToken;
    try {
      newToken = await _coordinatedRefresh();
    } on _RefreshFailure {
      _onLogout?.call();
      handler.reject(_collapsedException(err.requestOptions));
      return;
    } catch (_) {
      // Transient (5xx / network / timeout). Pass the ORIGINAL 401 through
      // unchanged and DO NOT clear tokens — the user can retry later.
      handler.next(err);
      return;
    }

    await _retryAndResolve(
      original: err.requestOptions,
      accessToken: newToken,
      attempts: attempts,
      handler: handler,
      originalErr: err,
    );
  }

  /// Replays the original request with [accessToken] and an incremented
  /// retry counter. Resolves the handler on success; on failure, forwards
  /// the new DioException (or the original 401 if something non-Dio blew up).
  Future<void> _retryAndResolve({
    required RequestOptions original,
    required String accessToken,
    required int attempts,
    required ErrorInterceptorHandler handler,
    required DioException originalErr,
  }) async {
    try {
      final retryOpts = _withAuth(
        original,
        accessToken: accessToken,
        attempts: attempts + 1,
      );
      final response = await _dioForRetry.fetch(retryOpts);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } catch (_) {
      handler.next(originalErr);
    }
  }

  /// Returns the in-flight refresh future, creating one if none is active.
  /// All concurrent 401s share this future — guaranteeing AT MOST ONE
  /// network call to `/auth/refresh`.
  Future<String> _coordinatedRefresh() {
    final existing = _refreshFuture;
    if (existing != null) return existing;
    final future = _doRefresh();
    _refreshFuture = future;
    return future;
  }

  /// Performs the actual refresh against the dedicated interceptor-less Dio.
  /// On unrecoverable failure (refresh token rejected, missing tokens,
  /// persistence failure) throws [_RefreshFailure]. On transient failure
  /// (5xx, network) rethrows the [DioException] so the caller can decide
  /// to pass through the original 401 instead of collapsing the session.
  Future<String> _doRefresh() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const _RefreshFailure('no refresh token in storage');
      }
      final Response<dynamic> response;
      try {
        response = await _refreshClient.post(
          kAuthRefreshPath,
          data: {'refreshToken': refreshToken},
          options: Options(headers: {'Authorization': null}),
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          await _storage.deleteTokens();
          throw const _RefreshFailure('refresh token rejected');
        }
        rethrow; // transient — caller passes original 401 through
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const _RefreshFailure('malformed refresh response');
      }
      final AuthResponse auth;
      try {
        auth = AuthResponse.fromJson(data);
      } on FormatException {
        throw const _RefreshFailure('malformed refresh envelope');
      }
      try {
        await _storage.saveTokens(
          accessToken: auth.accessToken,
          refreshToken: auth.refreshToken,
        );
      } catch (_) {
        throw const _RefreshFailure('failed to persist refreshed tokens');
      }
      return auth.accessToken;
    } finally {
      // ALWAYS clear the single-flight slot — even on failure — so the next
      // 401 can spawn a fresh refresh attempt instead of awaiting a dead future.
      _refreshFuture = null;
    }
  }

  /// Builds a fresh [RequestOptions] with the new bearer + bumped attempt
  /// counter. Never mutates [original].
  RequestOptions _withAuth(
    RequestOptions original, {
    required String accessToken,
    required int attempts,
  }) {
    final headers = <String, dynamic>{
      ...original.headers,
      'Authorization': 'Bearer $accessToken',
    };
    final extra = <String, dynamic>{
      ...original.extra,
      _kReqToken: accessToken,
      _kAttempts: attempts,
    };
    return original.copyWith(headers: headers, extra: extra);
  }

  /// Builds the sentinel [DioException] returned to callers when the auth
  /// flow has collapsed. Carries both an [AuthSessionCollapsed] in `error`
  /// and a `authFlowCollapsed: true` flag in `extra` so consumers have two
  /// independent detection channels.
  DioException _collapsedException(RequestOptions original) {
    final extra = <String, dynamic>{
      ...original.extra,
      kAuthFlowCollapsedExtra: true,
    };
    return DioException(
      requestOptions: original.copyWith(extra: extra),
      type: DioExceptionType.cancel,
      error: const AuthSessionCollapsed(),
      message: 'Auth session collapsed during refresh',
    );
  }

  /// Path comparison that tolerates the `/v1` baseUrl prefix vs. raw paths.
  bool _isRefreshPath(String path) => path.endsWith(kAuthRefreshPath);

  /// True when [path] is one of the anonymous auth endpoints (login or
  /// register). The interceptor must not run the refresh-and-retry dance
  /// for those — no Bearer was ever attached, and a 401 there means
  /// "credentials are wrong", not "session expired".
  bool _isAnonymousAuthPath(String path) =>
      path.endsWith(kAuthLoginPath) || path.endsWith(kAuthRegisterPath);
}
