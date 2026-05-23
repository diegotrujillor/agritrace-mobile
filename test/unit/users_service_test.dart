import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/services/users_service.dart';

import '_helpers.dart';

/// Builds a Dio [Response] with the given body and (optional) headers, so the
/// service can read `response.headers.value('x-export-truncated')`.
Response<Map<String, dynamic>> _exportResponse(
  Object? data, {
  Map<String, List<String>> headers = const {},
}) {
  return Response<Map<String, dynamic>>(
    data: data is Map<String, dynamic> ? data : null,
    statusCode: 200,
    requestOptions: RequestOptions(path: '/users/me/export'),
    headers: Headers.fromMap(headers),
  );
}

Map<String, dynamic> _fullBundle() => {
      'exportedAt': '2026-05-22T10:00:00.000Z',
      'user': {'id': 'u-1', 'email': 'diego@example.com'},
      'producer': {'id': 'p-1', 'fullName': 'Diego'},
      'farms': [
        {'id': 'farm-1', 'name': 'Finca El Roble'},
      ],
      'plots': [],
      'activities': [],
      'alerts': [],
      'truncated': false,
    };

void main() {
  late MockApiService api;
  late MockDio dio;
  late UsersService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = UsersService(api);
  });

  test('exportMe() unwraps the envelope and returns the inner bundle', () async {
    final bundle = _fullBundle();
    when(() => dio.get<Map<String, dynamic>>('/users/me/export'))
        .thenAnswer((_) async => _exportResponse({'success': true, 'data': bundle}));

    final result = await service.exportMe();

    expect(result.bundle, bundle);
    expect(result.bundle.containsKey('success'), isFalse,
        reason: 'transport envelope must NOT leak into the user-facing bundle');
    expect(result.truncated, isFalse);
  });

  test('exportMe() reports truncated=true when X-Export-Truncated header is set', () async {
    when(() => dio.get<Map<String, dynamic>>('/users/me/export')).thenAnswer(
      (_) async => _exportResponse(
        {'success': true, 'data': _fullBundle()},
        headers: {
          'x-export-truncated': ['true'],
        },
      ),
    );

    final result = await service.exportMe();

    expect(result.truncated, isTrue);
  });

  test('exportMe() reports truncated=false when header is absent', () async {
    when(() => dio.get<Map<String, dynamic>>('/users/me/export')).thenAnswer(
      (_) async => _exportResponse({'success': true, 'data': _fullBundle()}),
    );

    final result = await service.exportMe();

    expect(result.truncated, isFalse);
  });

  test('exportMe() throws FormatException carrying the error string when success=false', () async {
    when(() => dio.get<Map<String, dynamic>>('/users/me/export')).thenAnswer(
      (_) async => _exportResponse({'success': false, 'error': 'rate limited'}),
    );

    expect(
      service.exportMe(),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'message', 'rate limited'),
      ),
    );
  });

  test('exportMe() throws FormatException when envelope is malformed', () async {
    when(() => dio.get<Map<String, dynamic>>('/users/me/export'))
        .thenAnswer((_) async => _exportResponse({'success': true}));

    expect(service.exportMe(), throwsA(isA<FormatException>()));
  });

  test('deleteMe() DELETEs /users/me', () async {
    when(() => dio.delete<void>('/users/me'))
        .thenAnswer((_) async => Response<void>(
              requestOptions: RequestOptions(path: '/users/me'),
              statusCode: 204,
            ));

    await service.deleteMe();

    verify(() => dio.delete<void>('/users/me')).called(1);
  });
}
