import 'package:dio/dio.dart';

import '../models/feedback.dart';
import 'api_envelope.dart';
import 'api_service.dart';

/// Spanish user-facing message for the 5-per-day rate limit. Lives here
/// (not in `error_parser.dart`) because the limit is feedback-specific:
/// the generic `parseApiError` 429 message would over-report (e.g. login
/// rate limit is 5/15min, this one is 5/day).
const String kFeedbackRateLimitMessage =
    'Has alcanzado el límite de 5 reportes por día — intenta mañana.';

/// Thin wrapper over [ApiService] for the `POST /v1/feedback` endpoint.
///
/// Mirrors the convention of other domain services in `lib/services/`:
/// constructor injection of [ApiService], no Flutter deps, envelope
/// unwrapping via `api_envelope.dart`.
///
/// Contract (frozen — coordinated with backend agent for v0.5.0):
/// ```
/// POST /v1/feedback   (Bearer JWT)
/// Body: { message, category, appVersion, device: { model, platform, osVersion } }
/// 201:  { success: true, data: { issueUrl, issueNumber } }
/// 4xx/5xx: { success: false, error: string }
/// ```
class FeedbackService {
  const FeedbackService(this._api);

  final ApiService _api;

  /// Posts a user report. Returns the GitHub-issue URL + number on 201.
  ///
  /// Throws [FeedbackRateLimitException] on HTTP 429 (carries the Spanish
  /// user-facing message). All other transport/network errors propagate
  /// as [DioException] — consistent with the rest of the codebase, so
  /// `parseApiError` handles them uniformly. A `{ success: false }`
  /// envelope is mapped to [FormatException] carrying the server's
  /// `error` string (same shape as `UsersService.exportMe`).
  Future<FeedbackSubmitted> submit({
    required String message,
    FeedbackCategory category = FeedbackCategory.bug,
    required String appVersion,
    required FeedbackDevice device,
  }) async {
    try {
      final response = await _api.client.post<Map<String, dynamic>>(
        '/feedback',
        data: {
          'message': message,
          'category': category.apiValue,
          'appVersion': appVersion,
          'device': device.toJson(),
        },
      );
      final body = response.data;
      // Explicit `success: false` envelope (rare but possible on a 200 body).
      if (body is Map<String, dynamic> && body['success'] == false) {
        final error = body['error'];
        throw FormatException(
          error is String && error.isNotEmpty
              ? error
              : 'Invalid API response: success=false',
        );
      }
      return unwrapOne(body, FeedbackSubmitted.fromJson);
    } on DioException catch (e) {
      // 429 has a domain-specific message; everything else propagates.
      if (e.response?.statusCode == 429) {
        throw const FeedbackRateLimitException(kFeedbackRateLimitMessage);
      }
      rethrow;
    }
  }
}
