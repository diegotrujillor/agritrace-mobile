import 'package:dio/dio.dart';

/// Maps an authentication-related error into a user-facing Spanish message.
///
/// Centralizing this avoids drift between login and register screens and
/// surfaces the actual failure mode (auth vs. network vs. server) instead
/// of a single catch-all string.
String parseApiError(Object? error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Credenciales incorrectas';
    // 409 is currently only returned by `POST /v1/auth/register` for an email
    // that is already taken (see agritrace-backend/docs/openapi.yaml). The
    // message is register-specific because no other screen surfaces a 409.
    if (status == 409) return 'Ese email ya está registrado';
    // 429 covers both the auth-specific rate limiter (5 attempts / 15 min on
    // /auth/login + /auth/register) and the general API limiter.
    if (status == 429) {
      return 'Muchos intentos, intenta de nuevo en unos minutos';
    }
    if (status != null && status >= 500) {
      return 'Error del servidor, intenta más tarde';
    }
    if (error.response == null) {
      return 'Sin conexión, verifica tu internet';
    }
  }
  return 'Ocurrió un error, intenta de nuevo';
}
