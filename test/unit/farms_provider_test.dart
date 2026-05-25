import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/providers/farms_provider.dart';
import 'package:agritrace_mobile/repositories/farm_repository.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/farm_service.dart';
import 'package:agritrace_mobile/services/sync_orchestrator.dart';
import 'package:agritrace_mobile/services/sync_service.dart';

class MockFarmRepository extends Mock implements FarmRepository {}

class MockFarmService extends Mock implements FarmService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

SyncResult _emptySyncResult() => SyncResult(
      synced: 0,
      conflicts: 0,
      pulledChanges: const [],
      timestamp: DateTime.utc(2026, 5, 25),
    );

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
  late MockSyncOrchestrator mockOrchestrator;

  setUp(() {
    mockRepo = MockFarmRepository();
    mockService = MockFarmService();
    mockOrchestrator = MockSyncOrchestrator();
    // v1.9.9 — every mutation now fires `unawaited(orchestrator.run())`.
    // Default the mock to a successful empty result so the existing tests
    // (which never asserted on it) keep passing; the dedicated auto-sync
    // tests below override or verify per-case.
    when(() => mockOrchestrator.run(since: any(named: 'since')))
        .thenAnswer((_) async => _emptySyncResult());
  });

  /// Builds a container with the repository, service AND the orchestrator
  /// overridden. The orchestrator override is critical for v1.9.9: without
  /// it the auto-sync hook would hit the real provider which depends on
  /// repos/services that aren't wired in the test container.
  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          farmRepositoryProvider.overrideWithValue(mockRepo),
          farmServiceProvider.overrideWithValue(mockService),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
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

    // v1.9.0 — create() now returns the created Farm so the post-create
    // auto-nav flow can read its id, which means a repo failure must
    // throw (not just be captured in state). Both signals — the thrown
    // exception AND the notifier's error state — survive.
    await expectLater(
      container.read(farmsProvider.notifier).create(
            name: 'X',
            cropType: 'cacao',
            areaHectares: 1,
          ),
      throwsA(isA<Exception>()),
    );
    expect(container.read(farmsProvider).hasError, isTrue);
  });

  test('farmProvider.family looks up a single farm by id', () async {
    stubRepoDefaults([]);
    // v1.9.0 — farmProvider is now local-first. Stub the repo lookup to
    // return null so the provider falls through to the service.
    when(() => mockRepo.getById('farm-7')).thenAnswer((_) async => null);
    when(() => mockService.get('farm-7'))
        .thenAnswer((_) async => _farm(id: 'farm-7'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final farm = await container.read(farmProvider('farm-7').future);

    expect(farm.id, 'farm-7');
  });

  test('farmProvider.family returns local farm when present (bug #10)',
      () async {
    stubRepoDefaults([]);
    when(() => mockRepo.getById('farm-local'))
        .thenAnswer((_) async => _farm(id: 'farm-local'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final farm = await container.read(farmProvider('farm-local').future);

    expect(farm.id, 'farm-local');
    verifyNever(() => mockService.get(any()));
  });

  // v1.9.9 — P0 fix. Every successful mutation must fire a background
  // `unawaited(SyncOrchestrator.run())` push so a `pendingCreate`/
  // `pendingUpdate` row is durable on the server before `wipeAllUserData`
  // can destroy it.
  group('v1.9.9 auto-sync push on mutation (P0)', () {
    test('createFarm() triggers background sync push', () async {
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
          .thenAnswer((_) async => [_farm(id: 'new')]);

      await container.read(farmsProvider.notifier).create(
            name: 'Nueva',
            cropType: 'cacao',
            areaHectares: 5,
          );
      // The hook is fire-and-forget — give the microtask queue a tick to
      // drain so `verify` sees the call.
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOrchestrator.run(since: any(named: 'since')))
          .called(1);
    });

    test('updateFarm() triggers background sync push', () async {
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
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOrchestrator.run(since: any(named: 'since')))
          .called(1);
    });

    test('delete() triggers background sync push', () async {
      stubRepoDefaults([_farm()]);
      when(() => mockRepo.delete(any())).thenAnswer((_) async {});

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(farmsProvider.future);

      when(() => mockRepo.listAll()).thenAnswer((_) async => <Farm>[]);
      await container.read(farmsProvider.notifier).delete('farm-1');
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOrchestrator.run(since: any(named: 'since')))
          .called(1);
    });

    test('createFarm() does NOT trigger push when repo throws', () async {
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

      await expectLater(
        container.read(farmsProvider.notifier).create(
              name: 'X',
              cropType: 'cacao',
              areaHectares: 1,
            ),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(Duration.zero);

      // Nothing was persisted locally — pushing would just be an
      // empty no-op round trip; skip it to keep the request log clean.
      verifyNever(() => mockOrchestrator.run(since: any(named: 'since')));
    });

    test('auto-sync push failure does not break the mutation result',
        () async {
      stubRepoDefaults([]);
      when(() => mockRepo.create(
            name: any(named: 'name'),
            cropType: any(named: 'cropType'),
            areaHectares: any(named: 'areaHectares'),
            address: any(named: 'address'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
          )).thenAnswer((_) async => _farm(id: 'new'));
      // The push leg goes offline — must NOT bubble up to the caller.
      // Use `thenAnswer` (an async failure) instead of `thenThrow` (a
      // synchronous throw before the Future is returned) so the
      // `.catchError` hook in `_autoSyncPush` has a chance to catch it,
      // mirroring how real Dio failures arrive (asynchronously).
      when(() => mockOrchestrator.run(since: any(named: 'since')))
          .thenAnswer((_) async => throw Exception('network down'));

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(farmsProvider.future);

      when(() => mockRepo.listAll())
          .thenAnswer((_) async => [_farm(id: 'new')]);

      final created = await container.read(farmsProvider.notifier).create(
            name: 'Nueva',
            cropType: 'cacao',
            areaHectares: 5,
          );
      // Give the catchError microtask a chance to land so it doesn't leak
      // into the next test's uncaught error reporter.
      await Future<void>.delayed(Duration.zero);

      expect(created.id, 'new',
          reason: 'create still returns the local row even when push fails');
    });
  });
}
