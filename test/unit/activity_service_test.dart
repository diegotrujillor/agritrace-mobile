import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/services/activity_service.dart';

import '_helpers.dart';

Map<String, dynamic> _activityJson({String id = 'act-1'}) => {
      'id': id,
      'plotId': 'plot-1',
      'type': 'pest_control',
      'occurredAt': '2026-03-01T00:00:00.000Z',
      'createdAt': '2026-03-01T01:00:00.000Z',
      'description': 'Aplicación de control biológico',
    };

void main() {
  late MockApiService api;
  late MockDio dio;
  late ActivityService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = ActivityService(api);
  });

  test('listByPlot() GETs /plots/:plotId/activities', () async {
    when(() => dio.get('/plots/plot-1/activities')).thenAnswer(
      (_) async => okResponse(envelope([_activityJson()])),
    );

    final acts = await service.listByPlot('plot-1');

    expect(acts.single.type, ActivityType.pestControl);
    verify(() => dio.get('/plots/plot-1/activities')).called(1);
  });

  test('get() GETs /activities/:id', () async {
    when(() => dio.get('/activities/act-5')).thenAnswer(
      (_) async => okResponse(envelope(_activityJson(id: 'act-5'))),
    );

    final act = await service.get('act-5');

    expect(act.id, 'act-5');
  });

  test('create() POSTs /activities with wire type and ISO date', () async {
    when(() => dio.post('/activities', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_activityJson())),
    );

    final when0 = DateTime.utc(2026, 3, 1);
    await service.create(
      plotId: 'plot-1',
      type: ActivityType.pestControl,
      occurredAt: when0,
      description: 'Aplicación de control biológico',
    );

    final captured = verify(
      () => dio.post('/activities', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['plotId'], 'plot-1');
    expect(captured['type'], 'pest_control');
    expect(captured['occurredAt'], when0.toIso8601String());
    expect(captured['description'], 'Aplicación de control biológico');
  });

  test('create() omits empty description and photoUrl', () async {
    when(() => dio.post('/activities', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_activityJson())),
    );

    await service.create(
      plotId: 'plot-1',
      type: ActivityType.harvest,
      occurredAt: DateTime.utc(2026, 3, 2),
    );

    final captured = verify(
      () => dio.post('/activities', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured.containsKey('description'), isFalse);
    expect(captured.containsKey('photoUrl'), isFalse);
  });

  test('update() PUTs /activities/:id', () async {
    when(() => dio.put('/activities/act-1', data: any(named: 'data')))
        .thenAnswer((_) async => okResponse(envelope(_activityJson())));

    await service.update(
      id: 'act-1',
      plotId: 'plot-1',
      type: ActivityType.irrigation,
      occurredAt: DateTime.utc(2026, 3, 3),
      photoUrl: 'https://cdn/p.jpg',
    );

    final captured = verify(
      () => dio.put('/activities/act-1', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['type'], 'irrigation');
    expect(captured['photoUrl'], 'https://cdn/p.jpg');
  });

  test('delete() DELETEs /activities/:id', () async {
    when(() => dio.delete('/activities/act-1'))
        .thenAnswer((_) async => okResponse(null));

    await service.delete('act-1');

    verify(() => dio.delete('/activities/act-1')).called(1);
  });

  test('throws FormatException on malformed envelope', () async {
    when(() => dio.get('/plots/plot-1/activities'))
        .thenAnswer((_) async => okResponse({'success': true}));

    expect(service.listByPlot('plot-1'), throwsA(isA<FormatException>()));
  });

  test('propagates DioException from the client', () async {
    when(() => dio.get('/activities/act-1')).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/activities/act-1')),
    );

    expect(service.get('act-1'), throwsA(isA<DioException>()));
  });
}
