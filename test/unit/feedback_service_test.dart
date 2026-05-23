import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/feedback.dart';
import 'package:agritrace_mobile/services/feedback_service.dart';

import '_helpers.dart';

/// Builds a 201-shaped Dio response for `POST /v1/feedback`. Mirrors the
/// `okResponse` helper in `_helpers.dart` but exposes the typed
/// `Response<Map<String, dynamic>>` the service consumes via `.data`.
Response<Map<String, dynamic>> _createdResponse(Map<String, dynamic> data) {
  return Response<Map<String, dynamic>>(
    data: data,
    statusCode: 201,
    requestOptions: RequestOptions(path: '/feedback'),
  );
}

const _device = FeedbackDevice(
  model: 'Pixel 7 Pro',
  platform: 'android',
  osVersion: 'Android 14',
);

void main() {
  late MockApiService api;
  late MockDio dio;
  late FeedbackService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = FeedbackService(api);
  });

  test('submit() POSTs to /feedback with the contracted JSON body', () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
            data: any(named: 'data'))).thenAnswer(
      (_) async => _createdResponse(envelope({
        'issueUrl':
            'https://github.com/diegotrujillor/agritrace-mobile/issues/42',
        'issueNumber': 42,
      })),
    );

    await service.submit(
      message: 'No abre la pantalla de fincas',
      category: FeedbackCategory.bug,
      appVersion: '1.8.0+3',
      device: _device,
    );

    final captured = verify(
      () => dio.post<Map<String, dynamic>>('/feedback',
          data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;

    expect(captured['message'], 'No abre la pantalla de fincas');
    expect(captured['category'], 'bug');
    expect(captured['appVersion'], '1.8.0+3');
    expect(captured['device'], {
      'model': 'Pixel 7 Pro',
      'platform': 'android',
      'osVersion': 'Android 14',
    });
  });

  test('submit() maps FeedbackCategory.feature to its wire value', () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
            data: any(named: 'data'))).thenAnswer(
      (_) async => _createdResponse(envelope({
        'issueUrl': 'https://example/issues/1',
        'issueNumber': 1,
      })),
    );

    await service.submit(
      message: 'Sería útil agregar exportación CSV',
      category: FeedbackCategory.feature,
      appVersion: '1.8.0+3',
      device: _device,
    );

    final captured = verify(
      () => dio.post<Map<String, dynamic>>('/feedback',
          data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['category'], 'feature');
  });

  test('submit() returns FeedbackSubmitted from envelope-wrapped 201', () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
            data: any(named: 'data'))).thenAnswer(
      (_) async => _createdResponse(envelope({
        'issueUrl':
            'https://github.com/diegotrujillor/agritrace-mobile/issues/7',
        'issueNumber': 7,
      })),
    );

    final result = await service.submit(
      message: 'Mensaje válido con suficientes caracteres',
      appVersion: '1.8.0+3',
      device: _device,
    );

    expect(result.issueNumber, 7);
    expect(
      result.issueUrl,
      'https://github.com/diegotrujillor/agritrace-mobile/issues/7',
    );
  });

  test('submit() throws FeedbackRateLimitException on HTTP 429', () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
        data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/feedback'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/feedback'),
          statusCode: 429,
          data: {'success': false, 'error': 'rate limited'},
        ),
      ),
    );

    expect(
      service.submit(
        message: 'Mensaje válido con suficientes caracteres',
        appVersion: '1.8.0+3',
        device: _device,
      ),
      throwsA(
        isA<FeedbackRateLimitException>().having(
          (e) => e.userMessage,
          'userMessage',
          'Has alcanzado el límite de 5 reportes por día — intenta mañana.',
        ),
      ),
    );
  });

  test('submit() propagates DioException on 5xx', () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
        data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/feedback'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/feedback'),
          statusCode: 502,
        ),
      ),
    );

    expect(
      service.submit(
        message: 'Mensaje válido con suficientes caracteres',
        appVersion: '1.8.0+3',
        device: _device,
      ),
      throwsA(isA<DioException>()),
    );
  });

  test('submit() throws FormatException carrying server error when success=false',
      () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
            data: any(named: 'data')))
        .thenAnswer((_) async => _createdResponse(
              {'success': false, 'error': 'invalid input'},
            ));

    expect(
      service.submit(
        message: 'Mensaje válido con suficientes caracteres',
        appVersion: '1.8.0+3',
        device: _device,
      ),
      throwsA(
        isA<FormatException>()
            .having((e) => e.message, 'message', 'invalid input'),
      ),
    );
  });

  test('submit() throws FormatException when envelope is malformed', () async {
    when(() => dio.post<Map<String, dynamic>>('/feedback',
            data: any(named: 'data')))
        .thenAnswer((_) async => _createdResponse({'success': true}));

    expect(
      service.submit(
        message: 'Mensaje válido con suficientes caracteres',
        appVersion: '1.8.0+3',
        device: _device,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
