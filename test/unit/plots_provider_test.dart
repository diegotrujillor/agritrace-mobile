import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/services/plot_service.dart';

class MockPlotService extends Mock implements PlotService {}

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
  });

  late MockPlotService mockService;

  setUp(() {
    mockService = MockPlotService();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [plotServiceProvider.overrideWithValue(mockService)],
      );

  test('build() loads plots for the given farm', () async {
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot()]);
    final container = makeContainer();
    addTearDown(container.dispose);

    final plots = await container.read(plotsProvider(_farmId).future);

    expect(plots.single.name, 'Lote Norte');
    verify(() => mockService.listByFarm(_farmId)).called(1);
  });

  test('create() calls the service with the family farmId then refreshes',
      () async {
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => <Plot>[]);
    when(() => mockService.create(
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

    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot()]);
    await container.read(plotsProvider(_farmId).notifier).create(
          name: 'Lote Norte',
          cropType: 'cacao',
          status: PlotStatus.planning,
        );

    expect(container.read(plotsProvider(_farmId)).value, hasLength(1));
    verify(() => mockService.create(
          farmId: _farmId,
          name: 'Lote Norte',
          cropType: 'cacao',
          status: PlotStatus.planning,
          variety: null,
          areaHectares: null,
        )).called(1);
  });

  test('updatePlot() calls the service then refreshes', () async {
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot()]);
    when(() => mockService.update(
          id: any(named: 'id'),
          farmId: any(named: 'farmId'),
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          status: any(named: 'status'),
          variety: any(named: 'variety'),
          areaHectares: any(named: 'areaHectares'),
        )).thenAnswer((_) async => _plot(name: 'Lote Sur'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot(name: 'Lote Sur')]);
    await container.read(plotsProvider(_farmId).notifier).updatePlot(
          id: 'plot-1',
          name: 'Lote Sur',
          cropType: 'cacao',
          status: PlotStatus.ready,
        );

    expect(container.read(plotsProvider(_farmId)).value!.single.name,
        'Lote Sur');
    verify(() => mockService.update(
          id: 'plot-1',
          farmId: _farmId,
          name: 'Lote Sur',
          cropType: 'cacao',
          status: PlotStatus.ready,
          variety: null,
          areaHectares: null,
        )).called(1);
  });

  test('deletePlot() calls the service then refreshes', () async {
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => <Plot>[]);
    await container.read(plotsProvider(_farmId).notifier).deletePlot('plot-1');

    expect(container.read(plotsProvider(_farmId)).value, isEmpty);
    verify(() => mockService.delete('plot-1')).called(1);
  });

  test('build() surfaces an AsyncError when the service throws', () async {
    when(() => mockService.listByFarm(_farmId))
        .thenThrow(Exception('network down'));
    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(plotsProvider(_farmId).future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(plotsProvider(_farmId)).hasError, isTrue);
  });

  test('deletePlot() puts the notifier in error state when refresh fails',
      () async {
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_plot()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(plotsProvider(_farmId).future);

    when(() => mockService.listByFarm(_farmId))
        .thenThrow(Exception('refresh failed'));
    await container.read(plotsProvider(_farmId).notifier).deletePlot('plot-1');

    expect(container.read(plotsProvider(_farmId)).hasError, isTrue);
  });

  test('plotProvider.family looks up a single plot by id', () async {
    when(() => mockService.get('plot-9'))
        .thenAnswer((_) async => _plot(id: 'plot-9'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final plot = await container.read(plotProvider('plot-9').future);

    expect(plot.id, 'plot-9');
  });
}
