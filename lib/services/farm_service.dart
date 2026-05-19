import '../models/farm.dart';
import 'api_service.dart';

/// Thin wrapper over [ApiService] for the `/farms` endpoints.
///
/// Mirrors `AuthService`: no Flutter deps, dependency injected via
/// constructor, unwraps the `{ success, data }` envelope. The Bearer token
/// and 401-refresh are handled transparently by `_AuthInterceptor`, so every
/// call here is already authenticated.
class FarmService {
  const FarmService(this._api);

  final ApiService _api;

  /// `GET /farms` — the authenticated producer's own farms.
  Future<List<Farm>> list() async {
    final response = await _api.client.get('/farms');
    return _unwrapList(response.data);
  }

  /// `GET /farms/:id`.
  Future<Farm> get(String id) async {
    final response = await _api.client.get('/farms/$id');
    return _unwrapOne(response.data);
  }

  /// `POST /farms`.
  Future<Farm> create({
    required String name,
    required String cropType,
    required double areaHectares,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _api.client.post('/farms', data: {
      'name': name,
      'cropType': cropType,
      'areaHectares': areaHectares,
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return _unwrapOne(response.data);
  }

  /// `PUT /farms/:id`.
  Future<Farm> update({
    required String id,
    required String name,
    required String cropType,
    required double areaHectares,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _api.client.put('/farms/$id', data: {
      'name': name,
      'cropType': cropType,
      'areaHectares': areaHectares,
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return _unwrapOne(response.data);
  }

  /// `DELETE /farms/:id`.
  Future<void> delete(String id) async {
    await _api.client.delete('/farms/$id');
  }

  Farm _unwrapOne(Object? body) {
    final json = _envelope(body);
    return Farm.fromJson(json['data'] as Map<String, dynamic>);
  }

  List<Farm> _unwrapList(Object? body) {
    final json = _envelope(body);
    final data = json['data'] as List<dynamic>;
    return data
        .map((e) => Farm.fromJson(e as Map<String, dynamic>))
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
