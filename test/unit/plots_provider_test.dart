import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/plot_service.dart';
import 'package:agritrace_mobile/services/sync_orchestrator.dart';
import 'package:agritrace_mobile/services/sync_service.dart';

class MockPlotRepository extends Mock implements PlotRepository {}

class MockPlotService extends Mock implements PlotService {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

SyncResult _emptySyncResult() => SyncResult(
      synced: 0,
      conflicts: 0,
      pulledChanges: const [],
      timestamp: DateTime.utc(2026, 5, 25),
    );

const _farmId = 'farm-1';

Plot _plot({String id = 'plot-1', String name = 'Lote Norte'}) => Plot(
      id: id,
      farmId: _farmId,
      name: name,
      cropType: 'cacao',
      status: PlotStatus.growing,
      createdAt: DateTime.utc(2026, 2, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(PlotStatus.planning);
    registerFallbackValue(_plot());
  });

  late MockPlotRepository mockRepo;
  late MockPlotService mockService;
  late MockSyncOrchestrator mockOrchestrator;

  setUp(() {
    mockRepo = MockPlotRepository();
    mockService = MockPlotService();
    mockOrchestrator = MockSyncOrchestrator();
    // v1.9.9 — every mutation now fires `unawaited(orchestrator.run())`.
    when(() => mockOrchestrator.run(since: any(named: 'since')))
        .thenAnswer((_) async => _emptySyncResult());
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          plotRepositoryProvider.overrideWithValue(mockRepo),
          plotServiceProvider.overrideWithValue(mockService),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );

  void stubRepoDefaults(List<Plot> plots) {
    when(() => mockRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value(plots));
    when(() => mockRepo.listByFarm(any())).thenAnswer((_) async => plots);
  }

  test('build() loads plots for the given farm', () async {
    stubRepoDefaults([_plot()]);

    final container = makeContainer();
    addTearDown(container.dispose);

    final plots = await container.read(plotsProvider(_farmId).future);

    expect(plots.single.name, 'Lote Norte');
    verify(() => mockRepo.listByFarm(_farmId)).called(greaterThanOrEqualTo(1));
  });

  test('create() calls repo with the family farmId then refreshes', () async {
    stubRepoDefaults([]);
    when(() => mockRepo.create(
          farmId: any(named: 'farmId'),
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          status: any(named: 'status'),
          variety: any(named: 'variety'),
          areaHectares: any(named: 'areaHectares'),
        )).thenAnswer((_) async => _plot());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockRepo.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot()]);
    await container.read(plotsProvider(_farmId).notifier).create(
          name: 'Lote Norte',
          cropType: 'cacao',
          status: PlotStatus.planning,
        );

    expect(container.read(plotsProvider(_farmId)).value, hasLength(1));
    verify(() => mockRepo.create(
          farmId: _farmId,
          name: 'Lote Norte',
          cropType: 'cacao',
          status: PlotStatus.planning,
          variety: null,
          areaHectares: null,
        )).called(1);
  });

  test('updatePlot() calls repo update then refreshes', () async {
    stubRepoDefaults([_plot()]);
    when(() => mockRepo.update(
          any(),
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          status: any(named: 'status'),
          variety: any(named: 'variety'),
          areaHectares: any(named: 'areaHectares'),
        )).thenAnswer((_) async => _plot(name: 'Lote Sur'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockRepo.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot(name: 'Lote Sur')]);
    await container.read(plotsProvider(_farmId).notifier).updatePlot(
          id: 'plot-1',
          name: 'Lote Sur',
          cropType: 'cacao',
          status: PlotStatus.ready,
        );

    expect(container.read(plotsProvider(_farmId)).value!.single.name,
        'Lote Sur');
  });

  test('deletePlot() calls repo delete then refreshes', () async {
    stubRepoDefaults([_plot()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockRepo.listByFarm(_farmId))
        .thenAnswer((_) async => <Plot>[]);
    await container.read(plotsProvider(_farmId).notifier).deletePlot('plot-1');

    expect(container.read(plotsProvider(_farmId)).value, isEmpty);
    verify(() => mockRepo.delete('plot-1')).called(1);
  });

  test('build() surfaces an AsyncError when the repo throws', () async {
    when(() => mockRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.listByFarm(_farmId))
        .thenThrow(Exception('db error'));

    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(plotsProvider(_farmId).future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(plotsProvider(_farmId)).hasError, isTrue);
  });

  test('deletePlot() puts the notifier in error state when repo throws',
      () async {
    stubRepoDefaults([_plot()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockRepo.listByFarm(_farmId))
        .thenThrow(Exception('refresh failed'));
    await container.read(plotsProvider(_farmId).notifier).deletePlot('plot-1');

    expect(container.read(plotsProvider(_farmId)).hasError, isTrue);
  });

  test('plotProvider.family looks up a single plot by id', () async {
    // v1.9.0 — plotProvider is now local-first. Stub the repo lookup to
    // return null so the provider falls through to the service.
    when(() => mockRepo.getById('plot-9')).thenAnswer((_) async => null);
    when(() => mockService.get('plot-9'))
        .thenAnswer((_) async => _plot(id: 'plot-9'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final plot = await container.read(plotProvider('plot-9').future);

    expect(plot.id, 'plot-9');
  });

  test('plotProvider.family returns local plot when present (bug #20)',
      () async {
    when(() => mockRepo.getById('plot-local'))
        .thenAnswer((_) async => _plot(id: 'plot-local'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final plot = await container.read(plotProvider('plot-local').future);

    expect(plot.id, 'plot-local');
    verifyNever(() => mockService.get(any()));
  });

  // v1.9.9 — P0 fix. See farms_provider_test.dart for the rationale.
  group('v1.9.9 auto-sync push on mutation (P0)', () {
    test('create() triggers background sync push', () async {
      stubRepoDefaults([]);
      when(() => mockRepo.create(
            farmId: any(named: 'farmId'),
            name: any(named: 'name'),
            cropType: any(named: 'cropType'),
            status: any(named: 'status'),
            variety: any(named: 'variety'),
            areaHectares: any(named: 'areaHectares'),
          )).thenAnswer((_) async => _plot());

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(plotsProvider(_farmId).future);

      when(() => mockRepo.listByFarm(_farmId))
          .thenAnswer((_) async => [_plot()]);
      await container.read(plotsProvider(_farmId).notifier).create(
            name: 'Lote Norte',
            cropType: 'cacao',
            status: PlotStatus.planning,
          );
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOrchestrator.run(since: any(named: 'since')))
          .called(1);
    });

    test('updatePlot() triggers background sync push', () async {
      stubRepoDefaults([_plot()]);
      when(() => mockRepo.update(
            any(),
            name: any(named: 'name'),
            cropType: any(named: 'cropType'),
            status: any(named: 'status'),
            variety: any(named: 'variety'),
            areaHectares: any(named: 'areaHectares'),
          )).thenAnswer((_) async => _plot(name: 'Lote Sur'));

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(plotsProvider(_farmId).future);

      when(() => mockRepo.listByFarm(_farmId))
          .thenAnswer((_) async => [_plot(name: 'Lote Sur')]);
      await container.read(plotsProvider(_farmId).notifier).updatePlot(
            id: 'plot-1',
            name: 'Lote Sur',
            cropType: 'cacao',
            status: PlotStatus.ready,
          );
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOrchestrator.run(since: any(named: 'since')))
          .called(1);
    });

    test('deletePlot() triggers background sync push', () async {
      stubRepoDefaults([_plot()]);
      when(() => mockRepo.delete(any())).thenAnswer((_) async {});

      final container = makeContainer();
      addTearDown(container.dispose);
      await container.read(plotsProvider(_farmId).future);

      when(() => mockRepo.listByFarm(_farmId))
          .thenAnswer((_) async => <Plot>[]);
      await container
          .read(plotsProvider(_farmId).notifier)
          .deletePlot('plot-1');
      await Future<void>.delayed(Duration.zero);

      verify(() => mockOrchestrator.run(since: any(named: 'since')))
          .called(1);
    });
  });
}
