import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/providers/farms_provider.dart';
import 'package:agritrace_mobile/services/farm_service.dart';

class MockFarmService extends Mock implements FarmService {}

Farm _farm({String id = 'farm-1', String name = 'Finca El Roble'}) => Farm(
      id: id,
      name: name,
      cropType: 'cacao',
      areaHectares: 10,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late MockFarmService mockService;

  setUp(() {
    mockService = MockFarmService();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [farmServiceProvider.overrideWithValue(mockService)],
      );

  test('build() loads the producer farms list', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_farm()]);
    final container = makeContainer();
    addTearDown(container.dispose);

    final farms = await container.read(farmsProvider.future);

    expect(farms.single.name, 'Finca El Roble');
    verify(() => mockService.list()).called(1);
  });

  test('create() calls the service then refreshes the list', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_farm()]);
    when(() => mockService.create(
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          areaHectares: any(named: 'areaHectares'),
          address: any(named: 'address'),
        )).thenAnswer((_) async => _farm(id: 'new'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockService.list())
        .thenAnswer((_) async => [_farm(), _farm(id: 'new')]);
    await container.read(farmsProvider.notifier).create(
          name: 'Nueva',
          cropType: 'cacao',
          areaHectares: 5,
        );

    expect(container.read(farmsProvider).value, hasLength(2));
    verify(() => mockService.create(
          name: 'Nueva',
          cropType: 'cacao',
          areaHectares: 5,
          address: null,
        )).called(1);
  });

  test('updateFarm() calls the service then refreshes', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_farm()]);
    when(() => mockService.update(
          id: any(named: 'id'),
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          areaHectares: any(named: 'areaHectares'),
          address: any(named: 'address'),
        )).thenAnswer((_) async => _farm(name: 'Editada'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockService.list())
        .thenAnswer((_) async => [_farm(name: 'Editada')]);
    await container.read(farmsProvider.notifier).updateFarm(
          id: 'farm-1',
          name: 'Editada',
          cropType: 'cacao',
          areaHectares: 9,
        );

    expect(container.read(farmsProvider).value!.single.name, 'Editada');
    verify(() => mockService.update(
          id: 'farm-1',
          name: 'Editada',
          cropType: 'cacao',
          areaHectares: 9,
          address: null,
        )).called(1);
  });

  test('delete() calls the service then refreshes', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_farm()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockService.list()).thenAnswer((_) async => <Farm>[]);
    await container.read(farmsProvider.notifier).delete('farm-1');

    expect(container.read(farmsProvider).value, isEmpty);
    verify(() => mockService.delete('farm-1')).called(1);
  });

  test('build() surfaces an AsyncError when the service throws', () async {
    when(() => mockService.list()).thenThrow(Exception('network down'));
    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(farmsProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(farmsProvider).hasError, isTrue);
  });

  test('create() puts the notifier in error state when refresh fails',
      () async {
    when(() => mockService.list()).thenAnswer((_) async => [_farm()]);
    when(() => mockService.create(
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          areaHectares: any(named: 'areaHectares'),
          address: any(named: 'address'),
        )).thenAnswer((_) async => _farm());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockService.list()).thenThrow(Exception('refresh failed'));
    await container.read(farmsProvider.notifier).create(
          name: 'X',
          cropType: 'cacao',
          areaHectares: 1,
        );

    expect(container.read(farmsProvider).hasError, isTrue);
  });

  test('farmProvider.family looks up a single farm by id', () async {
    when(() => mockService.list()).thenAnswer((_) async => <Farm>[]);
    when(() => mockService.get('farm-7'))
        .thenAnswer((_) async => _farm(id: 'farm-7'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final farm = await container.read(farmProvider('farm-7').future);

    expect(farm.id, 'farm-7');
  });
}
