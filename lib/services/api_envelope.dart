/// Helpers for the backend `{ success, data }` response envelope.
///
/// Every service (`activity`, `farm`, `plot`, `alert`) previously carried an
/// identical private `_envelope`/`_unwrapOne`/`_unwrapList` trio. These
/// top-level functions replace those copies with a single shared seam while
/// preserving the exact error behaviour (a [FormatException] when the
/// envelope is missing or malformed).
library;

/// Validates and returns the raw envelope map.
///
/// Throws a [FormatException] when [body] is not a JSON object, when
/// `success` is not exactly `true`, or when `data` is null.
Map<String, dynamic> unwrapEnvelope(Object? body) {
  if (body is! Map<String, dynamic> ||
      body['success'] != true ||
      body['data'] == null) {
    throw const FormatException(
      'Invalid API response: missing data envelope',
    );
  }
  return body;
}

/// Unwraps the envelope and maps `data` (a JSON object) via [fromJson].
T unwrapOne<T>(Object? body, T Function(Map<String, dynamic>) fromJson) {
  final json = unwrapEnvelope(body);
  return fromJson(json['data'] as Map<String, dynamic>);
}

/// Unwraps the envelope and maps each element of the `data` list via
/// [fromJson]. Returns a fixed-length (non-growable) list, matching the
/// original service behaviour.
List<T> unwrapList<T>(Object? body, T Function(Map<String, dynamic>) fromJson) {
  final json = unwrapEnvelope(body);
  final data = json['data'] as List<dynamic>;
  return data
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
