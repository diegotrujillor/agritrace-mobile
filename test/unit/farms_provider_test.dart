import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/providers/farms_provider.dart';
import 'package:agritrace_mobile/repositories/farm_repository.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/farm_service.dart';

class MockFarmRepository extends Mock implements FarmRepository {}

class MockFarmService extends Mock implements FarmService {}

Farm _farm({String id = 'farm-1', String name = 'Finca El Roble'}) => Farm(
      id: id,
      name: name,
      cropType: 'cacao',
      areaHectares: 10,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_farm());
  });

  late MockFarmRepository mockRepo;
  late MockFarmService mockService;

  setUp(() {
    mockRepo = MockFarmRepository();
    mockService = MockFarmService();
  });

  /// Builds a container with both the repository and service overridden.
  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          farmRepositoryProvider.overrideWithValue(mockRepo),
          farmServiceProvider.overrideWithValue(mockService),
        ],
      );

  /// Stubs the stream and listAll so FarmsNotifier.build() doesn't hit
  /// the real DB.
  void stubRepoDefaults(List<Farm> farms) {
    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.value(farms));
    when(() => mockRepo.listAll()).thenAnswer((_) async => farms);
  }

  test('build() loads the producer farms list', () async {
    stubRepoDefaults([_farm()]);

    final container = makeContainer();
    addTearDown(container.dispose);

    final farms = await container.read(farmsProvider.future);

    expect(farms.single.name, 'Finca El Roble');
    verify(() => mockRepo.listAll()).called(greaterThanOrEqualTo(1));
  });

  test('create() writes to repo then refreshes the list', () async {
    stubRepoDefaults([]);
    when(() => mockRepo.create(
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          areaHectares: any(named: 'areaHectares'),
          address: any(named: 'address'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => _farm(id: 'new'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockRepo.listAll())
        .thenAnswer((_) async => [_farm(), _farm(id: 'new')]);
    await container.read(farmsProvider.notifier).create(
          name: 'Nueva',
          cropType: 'cacao',
          areaHectares: 5,
        );

    expect(container.read(farmsProvider).value, hasLength(2));
  });

  test('updateFarm() calls repo update then refreshes', () async {
    stubRepoDefaults([_farm()]);
    when(() => mockRepo.update(
          any(),
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          areaHectares: any(named: 'areaHectares'),
          address: any(named: 'address'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => _farm(name: 'Editada'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockRepo.listAll())
        .thenAnswer((_) async => [_farm(name: 'Editada')]);
    await container.read(farmsProvider.notifier).updateFarm(
          id: 'farm-1',
          name: 'Editada',
          cropType: 'cacao',
          areaHectares: 9,
        );

    expect(container.read(farmsProvider).value!.single.name, 'Editada');
  });

  test('delete() calls repo delete then refreshes', () async {
    stubRepoDefaults([_farm()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    when(() => mockRepo.listAll()).thenAnswer((_) async => <Farm>[]);
    await container.read(farmsProvider.notifier).delete('farm-1');

    expect(container.read(farmsProvider).value, isEmpty);
    verify(() => mockRepo.delete('farm-1')).called(1);
  });

  test('build() surfaces an AsyncError when the repo throws', () async {
    when(() => mockRepo.watchAll()).thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.listAll()).thenThrow(Exception('db error'));

    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(farmsProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(farmsProvider).hasError, isTrue);
  });

  test('create() puts the notifier in error state when repo throws', () async {
    stubRepoDefaults([_farm()]);
    when(() => mockRepo.create(
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          areaHectares: any(named: 'areaHectares'),
          address: any(named: 'address'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenThrow(Exception('create failed'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(farmsProvider.future);

    await container.read(farmsProvider.notifier).create(
          name: 'X',
          cropType: 'cacao',
          areaHectares: 1,
        );

    expect(container.read(farmsProvider).hasError, isTrue);
  });

  test('farmProvider.family looks up a single farm by id', () async {
    stubRepoDefaults([]);
    when(() => mockService.get('farm-7'))
        .thenAnswer((_) async => _farm(id: 'farm-7'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final farm = await container.read(farmProvider('farm-7').future);

    expect(farm.id, 'farm-7');
  });
}
