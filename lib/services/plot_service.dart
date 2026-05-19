import '../models/plot.dart';
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
    return _unwrapList(response.data);
  }

  /// `GET /plots/:id`.
  Future<Plot> get(String id) async {
    final response = await _api.client.get('/plots/$id');
    return _unwrapOne(response.data);
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
    return _unwrapOne(response.data);
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
    return _unwrapOne(response.data);
  }

  Plot _unwrapOne(Object? body) {
    final json = _envelope(body);
    return Plot.fromJson(json['data'] as Map<String, dynamic>);
  }

  List<Plot> _unwrapList(Object? body) {
    final json = _envelope(body);
    final data = json['data'] as List<dynamic>;
    return data
        .map((e) => Plot.fromJson(e as Map<String, dynamic>))
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
