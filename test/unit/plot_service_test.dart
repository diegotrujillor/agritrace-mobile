import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/services/plot_service.dart';

import '_helpers.dart';

Map<String, dynamic> _plotJson({String id = 'plot-1'}) => {
      'id': id,
      'farmId': 'farm-1',
      'name': 'Lote Norte',
      'cropType': 'cacao',
      'status': 'growing',
      'createdAt': '2026-02-01T00:00:00.000Z',
      'variety': 'CCN-51',
      'areaHectares': 3.2,
    };

void main() {
  late MockApiService api;
  late MockDio dio;
  late PlotService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = PlotService(api);
  });

  test('listByFarm() GETs /farms/:farmId/plots and unwraps list', () async {
    when(() => dio.get('/farms/farm-1/plots')).thenAnswer(
      (_) async => okResponse(envelope([_plotJson()])),
    );

    final plots = await service.listByFarm('farm-1');

    expect(plots.single.status, PlotStatus.growing);
    verify(() => dio.get('/farms/farm-1/plots')).called(1);
  });

  test('get() GETs /plots/:id', () async {
    when(() => dio.get('/plots/plot-7')).thenAnswer(
      (_) async => okResponse(envelope(_plotJson(id: 'plot-7'))),
    );

    final plot = await service.get('plot-7');

    expect(plot.id, 'plot-7');
  });

  test('create() POSTs /plots with status serialised by name', () async {
    when(() => dio.post('/plots', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_plotJson())),
    );

    await service.create(
      farmId: 'farm-1',
      name: 'Lote Norte',
      cropType: 'cacao',
      status: PlotStatus.ready,
      variety: 'CCN-51',
      areaHectares: 3.2,
    );

    final captured = verify(
      () => dio.post('/plots', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['farmId'], 'farm-1');
    expect(captured['status'], 'ready');
    expect(captured['variety'], 'CCN-51');
    expect(captured['areaHectares'], 3.2);
  });

  test('create() omits empty variety', () async {
    when(() => dio.post('/plots', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_plotJson())),
    );

    await service.create(
      farmId: 'farm-1',
      name: 'Lote',
      cropType: 'cacao',
      status: PlotStatus.planning,
    );

    final captured = verify(
      () => dio.post('/plots', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured.containsKey('variety'), isFalse);
    expect(captured.containsKey('areaHectares'), isFalse);
  });

  test('update() PUTs /plots/:id', () async {
    when(() => dio.put('/plots/plot-1', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_plotJson())),
    );

    await service.update(
      id: 'plot-1',
      farmId: 'farm-1',
      name: 'Lote Sur',
      cropType: 'cacao',
      status: PlotStatus.harvested,
    );

    final captured = verify(
      () => dio.put('/plots/plot-1', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['name'], 'Lote Sur');
    expect(captured['status'], 'harvested');
  });

  test('delete() DELETEs /plots/:id', () async {
    when(() => dio.delete('/plots/plot-1'))
        .thenAnswer((_) async => okResponse(null));

    await service.delete('plot-1');

    verify(() => dio.delete('/plots/plot-1')).called(1);
  });

  test('throws FormatException on malformed envelope', () async {
    when(() => dio.get('/farms/farm-1/plots'))
        .thenAnswer((_) async => okResponse('not-a-map'));

    expect(service.listByFarm('farm-1'), throwsA(isA<FormatException>()));
  });

  test('propagates DioException from the client', () async {
    when(() => dio.get('/plots/plot-1')).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/plots/plot-1')),
    );

    expect(service.get('plot-1'), throwsA(isA<DioException>()));
  });
}
