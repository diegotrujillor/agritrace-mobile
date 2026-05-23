import 'api_envelope.dart';
import 'api_service.dart';

/// Result of [UsersService.exportMe]: the user-facing Habeas Data bundle
/// already unwrapped from the `{ success, data }` API envelope, plus the
/// `X-Export-Truncated` flag.
///
/// `truncated == true` means at least one of the 4 collections in [bundle]
/// (`farms` / `plots` / `activities` / `alerts`) hit the backend's 10000-row
/// cap and is incomplete. The UI must warn the user in that case.
class UserExportResult {
  const UserExportResult({required this.bundle, required this.truncated});

  final Map<String, dynamic> bundle;
  final bool truncated;
}

/// Header name (lowercased — Dio normalises header keys) emitted by the
/// backend when [UserExportResult.bundle] was capped. Any non-empty value is
/// treated as truthy.
const String exportTruncatedHeader = 'x-export-truncated';

class UsersService {
  const UsersService(this._api);

  final ApiService _api;

  /// Calls `GET /v1/users/me/export` and returns the inner bundle plus the
  /// truncation flag. The transport envelope (`{ success, data }`) is
  /// unwrapped here so callers never have to know about it.
  ///
  /// Throws [FormatException] when the envelope is malformed or when
  /// `success` is `false` (the server-side `error` message is carried in
  /// the exception when present).
  Future<UserExportResult> exportMe() async {
    final response = await _api.client.get<Map<String, dynamic>>('/users/me/export');
    final body = response.data;
    if (body is Map<String, dynamic> && body['success'] == false) {
      final error = body['error'];
      throw FormatException(
        error is String && error.isNotEmpty
            ? error
            : 'Invalid API response: success=false',
      );
    }
    final envelope = unwrapEnvelope(body);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid API response: export bundle is not a JSON object',
      );
    }
    final truncatedHeader = response.headers.value(exportTruncatedHeader);
    return UserExportResult(
      bundle: data,
      truncated: truncatedHeader != null && truncatedHeader.isNotEmpty,
    );
  }

  Future<void> deleteMe() async {
    await _api.client.delete<void>('/users/me');
  }
}
