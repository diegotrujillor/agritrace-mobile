import '../models/activity.dart';
import 'api_service.dart';

/// Thin wrapper over [ApiService] for the `/activities` endpoints.
///
/// Mirrors `PlotService`/`FarmService`: no Flutter deps, constructor
/// injection, unwraps the `{ success, data }` envelope. Authentication is
/// handled transparently by `_AuthInterceptor`.
///
/// Activities are listed per plot (`/plots/:plotId/activities`) but created,
/// fetched, updated and deleted through the flat `/activities` collection.
class ActivityService {
  const ActivityService(this._api);

  final ApiService _api;

  /// `GET /plots/:plotId/activities` — activities recorded on a plot.
  Future<List<Activity>> listByPlot(String plotId) async {
    final response = await _api.client.get('/plots/$plotId/activities');
    return _unwrapList(response.data);
  }

  /// `GET /activities/:id`.
  Future<Activity> get(String id) async {
    final response = await _api.client.get('/activities/$id');
    return _unwrapOne(response.data);
  }

  /// `POST /activities`.
  Future<Activity> create({
    required String plotId,
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    final response = await _api.client.post('/activities', data: {
      'plotId': plotId,
      'type': type.wire,
      'occurredAt': occurredAt.toIso8601String(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return _unwrapOne(response.data);
  }

  /// `PUT /activities/:id`.
  Future<Activity> update({
    required String id,
    required String plotId,
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    final response = await _api.client.put('/activities/$id', data: {
      'plotId': plotId,
      'type': type.wire,
      'occurredAt': occurredAt.toIso8601String(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return _unwrapOne(response.data);
  }

  /// `DELETE /activities/:id`.
  Future<void> delete(String id) async {
    await _api.client.delete('/activities/$id');
  }

  Activity _unwrapOne(Object? body) {
    final json = _envelope(body);
    return Activity.fromJson(json['data'] as Map<String, dynamic>);
  }

  List<Activity> _unwrapList(Object? body) {
    final json = _envelope(body);
    final data = json['data'] as List<dynamic>;
    return data
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
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
