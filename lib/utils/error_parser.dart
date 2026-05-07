import 'package:dio/dio.dart';

/// Maps an authentication-related error into a user-facing Spanish message.
///
/// Centralizing this avoids drift between login and register screens and
/// surfaces the actual failure mode (auth vs. network vs. server) instead
/// of a single catch-all string.
String parseAuthError(Object? error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Credenciales incorrectas';
    if (status != null && status >= 500) {
      return 'Error del servidor, intenta más tarde';
    }
    if (error.response == null) {
      return 'Sin conexión, verifica tu internet';
    }
  }
  return 'Ocurrió un error, intenta de nuevo';
}
