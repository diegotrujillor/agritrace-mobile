import 'package:dio/dio.dart';

import '../services/api_service.dart';

/// Maps an authentication-related error into a user-facing Spanish message.
///
/// Centralizing this avoids drift between login and register screens and
/// surfaces the actual failure mode (auth vs. network vs. server) instead
/// of a single catch-all string.
String parseApiError(Object? error) {
  if (error is DioException) {
    // Detection channel 1: explicit sentinel produced by `_AuthInterceptor`
    // when the refresh flow itself collapsed (refresh token rejected, etc.).
    if (error.error is AuthSessionCollapsed) {
      return 'Sesión expirada. Vuelve a iniciar sesión.';
    }
    // Detection channel 2: extra flag set on the same path. Redundant with
    // the sentinel but cheap and survives DioException re-wrapping by
    // downstream code that strips `error` while preserving `requestOptions`.
    if (error.requestOptions.extra[kAuthFlowCollapsedExtra] == true) {
      return 'Sesión expirada. Vuelve a iniciar sesión.';
    }

    final status = error.response?.statusCode;
    if (status == 401) {
      // Split the raw-401 message by origin:
      //  - `/auth/login`         → wrong credentials at sign-in
      //  - any other endpoint    → domain authorization failure
      //                            (the auth-flow-collapsed case was already
      //                            caught above via the sentinel).
      final path = error.requestOptions.path;
      if (path.endsWith('/auth/login')) return 'Credenciales incorrectas';
      return 'No tienes permiso para ver esto.';
    }
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
