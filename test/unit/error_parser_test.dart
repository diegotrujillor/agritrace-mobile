import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/services/api_service.dart';
import 'package:agritrace_mobile/utils/error_parser.dart';

/// Helper that builds a [DioException] with a [Response] of the given
/// [statusCode]. Path defaults to a generic non-auth route — pass [path]
/// to exercise the per-endpoint 401 mapping.
DioException _httpError(int statusCode, {String path = '/x'}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
    ),
  );
}

void main() {
  group('parseApiError', () {
    test('401 on /auth/login → "Credenciales incorrectas"', () {
      expect(
        parseApiError(_httpError(401, path: '/auth/login')),
        'Credenciales incorrectas',
      );
    });

    test('401 on a domain endpoint → "No tienes permiso..."', () {
      expect(
        parseApiError(_httpError(401, path: '/farms')),
        'No tienes permiso para ver esto.',
      );
    });

    test('AuthSessionCollapsed sentinel → "Sesión expirada..."', () {
      // Arrange — interceptor reject path: error wraps the sentinel.
      final options = RequestOptions(path: '/farms');
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: const AuthSessionCollapsed(),
      );

      // Act + Assert
      expect(parseApiError(err), 'Sesión expirada. Vuelve a iniciar sesión.');
    });

    test('extra[authFlowCollapsed] flag → "Sesión expirada..."', () {
      // Arrange — second detection channel: requestOptions.extra flag,
      // for cases where downstream code strips `error` but preserves extra.
      final options = RequestOptions(
        path: '/farms',
        extra: const {kAuthFlowCollapsedExtra: true},
      );
      final err = DioException(requestOptions: options);

      // Act + Assert
      expect(parseApiError(err), 'Sesión expirada. Vuelve a iniciar sesión.');
    });

    test('returns email-duplicado message on 409 (register conflict)', () {
      // Arrange
      final err = _httpError(409);

      // Act
      final message = parseApiError(err);

      // Assert
      expect(message, 'Ese email ya está registrado');
    });

    test('returns rate-limit message on 429', () {
      // Arrange
      final err = _httpError(429);

      // Act
      final message = parseApiError(err);

      // Assert
      expect(message, 'Muchos intentos, intenta de nuevo en unos minutos');
    });

    test('returns server-error message on 500', () {
      expect(parseApiError(_httpError(500)),
          'Error del servidor, intenta más tarde');
    });

    test('returns server-error message on 503', () {
      expect(parseApiError(_httpError(503)),
          'Error del servidor, intenta más tarde');
    });

    test('returns offline message when there is no response (network down)', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
      );
      expect(parseApiError(err), 'Sin conexión, verifica tu internet');
    });

    test('returns generic fallback for non-special HTTP statuses (e.g. 400)', () {
      expect(parseApiError(_httpError(400)),
          'Ocurrió un error, intenta de nuevo');
    });

    test('returns generic fallback for non-Dio errors', () {
      expect(
          parseApiError(Exception('boom')), 'Ocurrió un error, intenta de nuevo');
    });

    test('returns generic fallback when error is null', () {
      expect(parseApiError(null), 'Ocurrió un error, intenta de nuevo');
    });
  });
}
