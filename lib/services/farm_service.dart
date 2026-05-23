import '../models/farm.dart';
import 'api_envelope.dart';
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
    return unwrapList(response.data, Farm.fromJson);
  }

  /// `GET /farms/:id`.
  Future<Farm> get(String id) async {
    final response = await _api.client.get('/farms/$id');
    return unwrapOne(response.data, Farm.fromJson);
  }

  /// `POST /farms`. v1.9.0 — `cropType` is optional at the farm level
  /// (free-text on the form, or skip). Empty/null is omitted so the
  /// backend stores SQL NULL and the relaxed Zod validator accepts it.
  Future<Farm> create({
    required String name,
    String? cropType,
    required double areaHectares,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _api.client.post('/farms', data: {
      'name': name,
      if (cropType != null && cropType.isNotEmpty) 'cropType': cropType,
      'areaHectares': areaHectares,
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return unwrapOne(response.data, Farm.fromJson);
  }

  /// `PUT /farms/:id`. See [create] for [cropType] handling.
  Future<Farm> update({
    required String id,
    required String name,
    String? cropType,
    required double areaHectares,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _api.client.put('/farms/$id', data: {
      'name': name,
      if (cropType != null && cropType.isNotEmpty) 'cropType': cropType,
      'areaHectares': areaHectares,
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return unwrapOne(response.data, Farm.fromJson);
  }

  /// `DELETE /farms/:id`.
  Future<void> delete(String id) async {
    await _api.client.delete('/farms/$id');
  }
}
