import '../models/alert.dart';
import 'api_service.dart';

/// Result of `POST /alerts/weather/check`. `alert` is null when the
/// provider is disabled (`none`) or the forecast was not actionable.
class WeatherCheckResult {
  const WeatherCheckResult({required this.provider, this.alert});

  /// `'none' | 'stub'` — server-configured weather provider.
  final String provider;
  final Alert? alert;
}

/// Thin wrapper over [ApiService] for the `/alerts` endpoints.
///
/// Mirrors `ActivityService`: no Flutter deps, constructor injection,
/// unwraps the `{ success, data }` envelope. Auth is handled transparently
/// by `_AuthInterceptor`.
class AlertService {
  const AlertService(this._api);

  final ApiService _api;

  /// `GET /alerts` — alerts for the authenticated producer, newest first.
  /// Optional [status] / [type] filters map to query params.
  Future<List<Alert>> list({AlertStatus? status, AlertType? type}) async {
    final response = await _api.client.get('/alerts', queryParameters: {
      if (status != null) 'status': status.wire,
      if (type != null) 'type': type.wire,
    });
    return _unwrapList(response.data);
  }

  /// `POST /alerts` — create a scheduled reminder.
  Future<Alert> createReminder({
    required String title,
    required DateTime scheduledFor,
    String? body,
    String? plotId,
  }) async {
    final response = await _api.client.post('/alerts', data: {
      'type': AlertType.reminder.wire,
      'title': title,
      'scheduledFor': scheduledFor.toIso8601String(),
      if (body != null && body.isNotEmpty) 'body': body,
      if (plotId != null && plotId.isNotEmpty) 'plotId': plotId,
    });
    return _unwrapOne(response.data);
  }

  /// `PATCH /alerts/:id` — partial update (dismiss, edit reminder).
  Future<Alert> update(
    String id, {
    AlertStatus? status,
    String? title,
    String? body,
  }) async {
    final response = await _api.client.patch('/alerts/$id', data: {
      if (status != null) 'status': status.wire,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
    return _unwrapOne(response.data);
  }

  /// `DELETE /alerts/:id` — soft-delete.
  Future<void> delete(String id) async {
    await _api.client.delete('/alerts/$id');
  }

  /// `POST /alerts/weather/check` — ask the server to run its weather
  /// provider for a plot and, if actionable, raise a weather alert.
  Future<WeatherCheckResult> checkWeather(String plotId) async {
    final response = await _api.client.post(
      '/alerts/weather/check',
      data: {'plotId': plotId},
    );
    final data = _envelope(response.data)['data'] as Map<String, dynamic>;
    final rawAlert = data['alert'];
    return WeatherCheckResult(
      provider: data['provider'] as String? ?? 'none',
      alert: rawAlert is Map<String, dynamic>
          ? Alert.fromJson(rawAlert)
          : null,
    );
  }

  Alert _unwrapOne(Object? body) {
    final json = _envelope(body);
    return Alert.fromJson(json['data'] as Map<String, dynamic>);
  }

  List<Alert> _unwrapList(Object? body) {
    final json = _envelope(body);
    final data = json['data'] as List<dynamic>;
    return data
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Map<String, dynamic> _envelope(Object? body) {
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] == null) {
      throw const FormatException(
        'Invalid API response: missing data envelope',
      );
    }
    return body;
  }
}
