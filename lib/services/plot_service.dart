import '../models/plot.dart';
import 'api_envelope.dart';
import 'api_service.dart';

/// Thin wrapper over [ApiService] for the `/plots` endpoints.
///
/// Mirrors `FarmService`/`AuthService`: no Flutter deps, constructor
/// injection, unwraps the `{ success, data }` envelope. Authentication is
/// handled transparently by `_AuthInterceptor`.
class PlotService {
  const PlotService(this._api);

  final ApiService _api;

  /// `GET /farms/:farmId/plots` — plots belonging to a farm.
  Future<List<Plot>> listByFarm(String farmId) async {
    final response = await _api.client.get('/farms/$farmId/plots');
    return unwrapList(response.data, Plot.fromJson);
  }

  /// `GET /plots/:id`.
  Future<Plot> get(String id) async {
    final response = await _api.client.get('/plots/$id');
    return unwrapOne(response.data, Plot.fromJson);
  }

  /// `POST /plots`.
  Future<Plot> create({
    required String farmId,
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    final response = await _api.client.post('/plots', data: {
      'farmId': farmId,
      'name': name,
      'cropType': cropType,
      'status': status.name,
      if (variety != null && variety.isNotEmpty) 'variety': variety,
      if (areaHectares != null) 'areaHectares': areaHectares,
    });
    return unwrapOne(response.data, Plot.fromJson);
  }

  /// `PUT /plots/:id`.
  Future<Plot> update({
    required String id,
    required String farmId,
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    final response = await _api.client.put('/plots/$id', data: {
      'farmId': farmId,
      'name': name,
      'cropType': cropType,
      'status': status.name,
      if (variety != null && variety.isNotEmpty) 'variety': variety,
      if (areaHectares != null) 'areaHectares': areaHectares,
    });
    return unwrapOne(response.data, Plot.fromJson);
  }

  /// `DELETE /plots/:id`.
  Future<void> delete(String id) async {
    await _api.client.delete('/plots/$id');
  }
}
