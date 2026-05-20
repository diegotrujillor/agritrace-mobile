import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/utils/error_parser.dart';

/// Helper that builds a [DioException] with a [Response] of the given
/// [statusCode]. Path is irrelevant for the parser — only the status
/// and presence of a response matter.
DioException _httpError(int statusCode) {
  final options = RequestOptions(path: '/x');
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
    test('returns Spanish message on 401', () {
      expect(parseApiError(_httpError(401)), 'Credenciales incorrectas');
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
