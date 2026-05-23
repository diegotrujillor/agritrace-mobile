import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/upload.dart';
import 'api_envelope.dart';
import 'api_service.dart';

/// Spanish user-facing message for the 10-per-5min rate limit on
/// `POST /v1/uploads/photos`. Lives here (not in `error_parser.dart`)
/// because the limit is upload-specific.
const String kUploadRateLimitMessage =
    'Has alcanzado el límite de subidas — intenta de nuevo en unos minutos.';

/// Spanish user-facing message for the 5 MB cap returned as HTTP 413 by
/// the backend or surfaced locally by [UploadsService.uploadPhoto] when
/// the file size exceeds [kMaxUploadBytes] before sending.
const String kUploadTooLargeMessage =
    'La foto es demasiado grande (máximo 5 MB). Toma una foto con menor resolución.';

/// Hard limit on the request body: matches the backend's `multer` cap so
/// we fail fast client-side instead of paying for a round-trip rejection.
const int kMaxUploadBytes = 5 * 1024 * 1024;

/// Thin wrapper over [ApiService] for the `POST /v1/uploads/photos`
/// multipart endpoint.
///
/// Mirrors [FeedbackService]: constructor injection of [ApiService], no
/// Flutter deps (so the service is unit-testable without a binding),
/// envelope unwrapping via `api_envelope.dart`. The Bearer token and
/// 401-refresh flow are owned by `_AuthInterceptor`.
///
/// Contract (frozen — coordinated with backend v0.6.0):
/// ```
/// POST /v1/uploads/photos          (Bearer JWT, multipart/form-data)
/// Body field: photo (image/jpeg | image/png; max 5 MB)
/// 201:  { success: true, data: { url, key, size, contentType } }
/// 400:  no file / wrong mime / too big (server-side detection)
/// 401:  missing / expired token
/// 413:  payload exceeds the multer limit
/// 429:  rate-limited (10 uploads / 5 min)
/// 502:  S3 upstream failure
/// ```
class UploadsService {
  const UploadsService(this._api);

  final ApiService _api;

  /// Uploads [bytes] to the photos endpoint and returns the parsed
  /// [UploadResponse] on HTTP 201.
  ///
  /// [filename] is sent verbatim as the multipart filename (used by the
  /// backend for logging only — the storage key is server-generated).
  /// [contentType] must be `image/jpeg` or `image/png`; anything else
  /// will be rejected by the backend with a 400.
  ///
  /// Throws [UploadTooLargeException] *before* hitting the network when
  /// [bytes] exceeds [kMaxUploadBytes] — saves the user a slow round-trip
  /// on a flaky connection. The same exception is also thrown on HTTP 413
  /// (server-side cap). Throws [UploadRateLimitException] on HTTP 429.
  /// All other transport errors propagate as [DioException] so
  /// `parseApiError` can render the generic copy.
  Future<UploadResponse> uploadPhoto({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    if (bytes.length > kMaxUploadBytes) {
      throw const UploadTooLargeException(kUploadTooLargeMessage);
    }
    final MediaType media;
    try {
      media = MediaType.parse(contentType);
    } on FormatException {
      // Defensive: a caller passing an unparseable content-type would
      // otherwise blow up inside Dio's MultipartFile constructor with a
      // confusing stack. Surface a clearer error instead.
      throw FormatException(
        'Invalid content-type for upload: $contentType',
      );
    }

    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: media,
      ),
    });

    try {
      final response = await _api.client.post<Map<String, dynamic>>(
        '/uploads/photos',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      final body = response.data;
      // Explicit `success: false` envelope (rare on a 200 body but cheap to handle).
      if (body is Map<String, dynamic> && body['success'] == false) {
        final error = body['error'];
        throw FormatException(
          error is String && error.isNotEmpty
              ? error
              : 'Invalid upload response: success=false',
        );
      }
      return unwrapOne(body, UploadResponse.fromJson);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) {
        throw const UploadRateLimitException(kUploadRateLimitMessage);
      }
      if (status == 413) {
        throw const UploadTooLargeException(kUploadTooLargeMessage);
      }
      rethrow;
    }
  }
}
