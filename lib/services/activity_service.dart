import '../models/activity.dart';
import 'api_envelope.dart';
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

  /// `GET /activities/plots/:plotId/activities` — activities of a plot.
  ///
  /// Backend mounts the activities router at `/v1/activities`, so the
  /// nested list lives at `/v1/activities/plots/{plotId}/activities`.
  /// Earlier the path was `/plots/{plotId}/activities` and returned 404
  /// silently — fixed in v1.3.5.
  Future<List<Activity>> listByPlot(String plotId) async {
    final response = await _api.client.get('/activities/plots/$plotId/activities');
    return unwrapList(response.data, Activity.fromJson);
  }

  /// `GET /activities/:id`.
  Future<Activity> get(String id) async {
    final response = await _api.client.get('/activities/$id');
    return unwrapOne(response.data, Activity.fromJson);
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
      // .toUtc() so the ISO string carries the 'Z' suffix the backend
      // Zod `.datetime()` validator requires.
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return unwrapOne(response.data, Activity.fromJson);
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
      // .toUtc() so the ISO string carries the 'Z' suffix the backend
      // Zod `.datetime()` validator requires.
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      if (description != null && description.isNotEmpty)
        'description': description,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
    });
    return unwrapOne(response.data, Activity.fromJson);
  }

  /// `DELETE /activities/:id`.
  Future<void> delete(String id) async {
    await _api.client.delete('/activities/$id');
  }
}
