import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/alert.dart';
import 'package:agritrace_mobile/services/alert_service.dart';

import '_helpers.dart';

Map<String, dynamic> _alertJson({String id = 'alert-1'}) => {
      'id': id,
      'type': 'reminder',
      'severity': 'warning',
      'title': 'Regar el lote norte',
      'status': 'pending',
      'createdAt': '2026-04-01T00:00:00.000Z',
      'plotId': 'plot-1',
      'body': 'Recordatorio de riego',
      'scheduledFor': '2026-04-02T08:00:00.000Z',
    };

void main() {
  late MockApiService api;
  late MockDio dio;
  late AlertService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = AlertService(api);
  });

  test('list() GETs /alerts with no filters by default', () async {
    when(() => dio.get('/alerts', queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => okResponse(envelope([_alertJson()])));

    final alerts = await service.list();

    expect(alerts.single.type, AlertType.reminder);
    final q = verify(
      () => dio.get('/alerts',
          queryParameters: captureAny(named: 'queryParameters')),
    ).captured.single as Map;
    expect(q.isEmpty, isTrue);
  });

  test('list() maps status and type filters to query params', () async {
    when(() => dio.get('/alerts', queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => okResponse(envelope([])));

    await service.list(status: AlertStatus.dismissed, type: AlertType.weather);

    final q = verify(
      () => dio.get('/alerts',
          queryParameters: captureAny(named: 'queryParameters')),
    ).captured.single as Map;
    expect(q['status'], 'dismissed');
    expect(q['type'], 'weather');
  });

  test('createReminder() POSTs /alerts with reminder type', () async {
    when(() => dio.post('/alerts', data: any(named: 'data')))
        .thenAnswer((_) async => okResponse(envelope(_alertJson())));

    await service.createReminder(
      title: 'Regar el lote norte',
      scheduledFor: DateTime.utc(2026, 4, 2, 8),
      body: 'Recordatorio de riego',
      plotId: 'plot-1',
    );

    final captured = verify(
      () => dio.post('/alerts', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['type'], 'reminder');
    expect(captured['title'], 'Regar el lote norte');
    expect(captured['scheduledFor'], DateTime.utc(2026, 4, 2, 8).toIso8601String());
    expect(captured['plotId'], 'plot-1');
  });

  test('update() PATCHes /alerts/:id with provided fields only', () async {
    when(() => dio.patch('/alerts/alert-1', data: any(named: 'data')))
        .thenAnswer((_) async => okResponse(envelope(_alertJson())));

    await service.update('alert-1', status: AlertStatus.dismissed);

    final captured = verify(
      () => dio.patch('/alerts/alert-1', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['status'], 'dismissed');
    expect(captured.containsKey('title'), isFalse);
  });

  test('delete() DELETEs /alerts/:id', () async {
    when(() => dio.delete('/alerts/alert-1'))
        .thenAnswer((_) async => okResponse(null));

    await service.delete('alert-1');

    verify(() => dio.delete('/alerts/alert-1')).called(1);
  });

  test('checkWeather() POSTs /alerts/weather/check and parses result', () async {
    when(() => dio.post('/alerts/weather/check', data: any(named: 'data')))
        .thenAnswer(
      (_) async => okResponse(envelope({
        'provider': 'stub',
        'alert': _alertJson(id: 'wx-1'),
      })),
    );

    final result = await service.checkWeather('plot-1');

    expect(result.provider, 'stub');
    expect(result.alert?.id, 'wx-1');
    final captured = verify(
      () => dio.post('/alerts/weather/check',
          data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['plotId'], 'plot-1');
  });

  test('checkWeather() returns null alert when none raised', () async {
    when(() => dio.post('/alerts/weather/check', data: any(named: 'data')))
        .thenAnswer(
      (_) async => okResponse(envelope({'provider': 'none', 'alert': null})),
    );

    final result = await service.checkWeather('plot-1');

    expect(result.provider, 'none');
    expect(result.alert, isNull);
  });

  test('throws FormatException on malformed envelope', () async {
    when(() => dio.get('/alerts', queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => okResponse({'success': false}));

    expect(service.list(), throwsA(isA<FormatException>()));
  });

  test('propagates DioException from the client', () async {
    when(() => dio.delete('/alerts/alert-1')).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/alerts/alert-1')),
    );

    expect(service.delete('alert-1'), throwsA(isA<DioException>()));
  });
}
