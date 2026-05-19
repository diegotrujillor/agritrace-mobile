import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/services/farm_service.dart';

import '_helpers.dart';

Map<String, dynamic> _farmJson({String id = 'farm-1'}) => {
      'id': id,
      'name': 'Finca El Roble',
      'cropType': 'cacao',
      'areaHectares': 12.5,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'address': 'Vereda La Esthela',
    };

void main() {
  late MockApiService api;
  late MockDio dio;
  late FarmService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = FarmService(api);
  });

  test('list() GETs /farms and unwraps the data list', () async {
    when(() => dio.get('/farms')).thenAnswer(
      (_) async => okResponse(envelope([_farmJson(), _farmJson(id: 'farm-2')])),
    );

    final farms = await service.list();

    expect(farms, hasLength(2));
    expect(farms.first.name, 'Finca El Roble');
    verify(() => dio.get('/farms')).called(1);
  });

  test('get() GETs /farms/:id and unwraps a single object', () async {
    when(() => dio.get('/farms/farm-9')).thenAnswer(
      (_) async => okResponse(envelope(_farmJson(id: 'farm-9'))),
    );

    final farm = await service.get('farm-9');

    expect(farm.id, 'farm-9');
    verify(() => dio.get('/farms/farm-9')).called(1);
  });

  test('create() POSTs /farms with the expected payload', () async {
    when(() => dio.post('/farms', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_farmJson())),
    );

    final farm = await service.create(
      name: 'Finca El Roble',
      cropType: 'cacao',
      areaHectares: 12.5,
      address: 'Vereda La Esthela',
    );

    expect(farm.id, 'farm-1');
    final captured = verify(
      () => dio.post('/farms', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['name'], 'Finca El Roble');
    expect(captured['cropType'], 'cacao');
    expect(captured['areaHectares'], 12.5);
    expect(captured['address'], 'Vereda La Esthela');
  });

  test('create() omits empty address from the payload', () async {
    when(() => dio.post('/farms', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_farmJson())),
    );

    await service.create(name: 'F', cropType: 'cacao', areaHectares: 1);

    final captured = verify(
      () => dio.post('/farms', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured.containsKey('address'), isFalse);
  });

  test('update() PUTs /farms/:id with the expected payload', () async {
    when(() => dio.put('/farms/farm-1', data: any(named: 'data'))).thenAnswer(
      (_) async => okResponse(envelope(_farmJson())),
    );

    await service.update(
      id: 'farm-1',
      name: 'Nuevo',
      cropType: 'cana',
      areaHectares: 8,
      latitude: 3.4,
      longitude: -76.5,
    );

    final captured = verify(
      () => dio.put('/farms/farm-1', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['name'], 'Nuevo');
    expect(captured['latitude'], 3.4);
    expect(captured['longitude'], -76.5);
  });

  test('delete() DELETEs /farms/:id', () async {
    when(() => dio.delete('/farms/farm-1'))
        .thenAnswer((_) async => okResponse(null));

    await service.delete('farm-1');

    verify(() => dio.delete('/farms/farm-1')).called(1);
  });

  test('throws FormatException when envelope is malformed', () async {
    when(() => dio.get('/farms'))
        .thenAnswer((_) async => okResponse({'success': false}));

    expect(service.list(), throwsA(isA<FormatException>()));
  });

  test('propagates DioException from the client', () async {
    when(() => dio.get('/farms')).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/farms')),
    );

    expect(service.list(), throwsA(isA<DioException>()));
  });
}
