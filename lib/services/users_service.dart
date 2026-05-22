import 'api_service.dart';

class UsersService {
  const UsersService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> exportMe() async {
    final response = await _api.client.get<Map<String, dynamic>>('/users/me/export');
    return response.data ?? {};
  }

  Future<void> deleteMe() async {
    await _api.client.delete<void>('/users/me');
  }
}
