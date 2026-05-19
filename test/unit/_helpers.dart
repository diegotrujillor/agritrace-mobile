import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/services/api_service.dart';

/// Shared test doubles for service-layer tests.
///
/// Services depend on [ApiService] only through its `client` getter (a Dio
/// instance), so mocking that pair is the correct seam: no real HTTP, no
/// `API_BASE_URL` dart-define needed (the real `ApiService` constructor is
/// never invoked).
class MockApiService extends Mock implements ApiService {}

class MockDio extends Mock implements Dio {}

/// Builds a Dio [Response] with [data] for stubbing client calls.
Response<dynamic> okResponse(Object? data, {String path = '/'}) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

/// Standard `{ success, data }` envelope wrapper used by the backend.
Map<String, dynamic> envelope(Object? data) => {
      'success': true,
      'data': data,
    };
