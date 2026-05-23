/// DTOs for the `POST /v1/uploads/photos` photo-upload endpoint (frozen
/// contract — coordinated with `agritrace-backend` v0.6.0).
///
/// Wire shape:
/// ```
/// 201: { success: true, data: { url, key, size, contentType } }
/// ```
library;

/// Successful result of [UploadsService.uploadPhoto]. The `url` is a public
/// (or pre-signed) HTTPS URL that callers persist into the owning entity
/// (e.g. `activity.photoUrl`) before issuing the domain create/update.
class UploadResponse {
  const UploadResponse({
    required this.url,
    required this.key,
    required this.size,
    required this.contentType,
  });

  /// Resolvable URL the client can render in an `Image.network` widget and
  /// the backend can serve back as part of the activity payload.
  final String url;

  /// Opaque storage key (S3 object key on the prod stack). Persisted to the
  /// upstream record so the backend can clean up orphans.
  final String key;

  /// Size in bytes of the uploaded file, post-multipart parsing. Matches
  /// the `size` field the backend logs for the upload audit trail.
  final int size;

  /// MIME type that the backend recorded for the object — useful for the
  /// rendering layer (jpeg vs png) and parity with the backend log.
  final String contentType;

  /// Parses the inner `data` payload of the `{ success, data }` envelope.
  /// Throws [FormatException] on missing or mistyped fields.
  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final key = json['key'];
    final size = json['size'];
    final contentType = json['contentType'] ?? json['content_type'];
    if (url is! String || url.isEmpty) {
      throw const FormatException(
        'Invalid upload response: url is missing or empty',
      );
    }
    if (key is! String || key.isEmpty) {
      throw const FormatException(
        'Invalid upload response: key is missing or empty',
      );
    }
    if (size is! num) {
      throw const FormatException(
        'Invalid upload response: size is missing or not numeric',
      );
    }
    if (contentType is! String || contentType.isEmpty) {
      throw const FormatException(
        'Invalid upload response: contentType is missing or empty',
      );
    }
    return UploadResponse(
      url: url,
      key: key,
      size: size.toInt(),
      contentType: contentType,
    );
  }
}

/// Thrown when the backend rejects an upload with HTTP 429 (10/5min rate
/// limit per the v0.6.0 contract). Carries a Spanish user-facing message so
/// the UI can render it without going through the generic `parseApiError`.
class UploadRateLimitException implements Exception {
  const UploadRateLimitException(this.userMessage);

  /// Spanish user-facing copy.
  final String userMessage;

  @override
  String toString() => 'UploadRateLimitException($userMessage)';
}

/// Thrown when the backend rejects the upload because the file is too
/// large (HTTP 413). Backend caps at 5 MB per the v0.6.0 contract; the
/// UI message reflects that bound.
class UploadTooLargeException implements Exception {
  const UploadTooLargeException(this.userMessage);

  /// Spanish user-facing copy.
  final String userMessage;

  @override
  String toString() => 'UploadTooLargeException($userMessage)';
}
