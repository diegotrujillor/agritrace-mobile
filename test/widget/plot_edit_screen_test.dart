// Widget tests for the plot edit screen (CU-12).
//
// Verifies that:
//   1. The form is prefilled from the loaded plot (name, variety, area).
//   2. Submitting calls PlotService.update with the edited values + shows
//      the "Lote actualizado" snackbar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/screens/plots/plot_edit_screen.dart';
import 'package:agritrace_mobile/services/plot_service.dart';

class _MockPlotService extends Mock implements PlotService {}

class _MockPlotRepository extends Mock implements PlotRepository {}

const _farmId = 'farm-1';
const _plotId = 'plot-1';

Plot _seedPlot() => Plot(
      id: _plotId,
      farmId: _farmId,
      name: 'Lote Norte',
      cropType: 'cacao',
      status: PlotStatus.growing,
      // Distinct from the form hints ('CCN-51', '2.5') so a `findOne` match
      // is unambiguous in the prefill assertion.
      variety: 'Trinitario',
      areaHectares: 4.2,
      createdAt: DateTime.utc(2026, 2, 1),
    );

GoRouter _router() => GoRouter(
      initialLocation: '/plots/$_plotId/edit',
      routes: [
        GoRoute(
          path: '/plots/:id/edit',
          builder: (_, state) =>
              PlotEditScreen(plotId: state.pathParameters['id']!),
        ),
        // Landing route the screen pops back to.
        GoRoute(
          path: '/back',
          builder: (_, __) => const Scaffold(body: Text('BACK')),
        ),
      ],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(PlotStatus.planning);
    registerFallbackValue(_seedPlot());
  });

  late _MockPlotService mockService;
  late _MockPlotRepository mockPlotRepo;

  setUp(() {
    mockService = _MockPlotService();
    mockPlotRepo = _MockPlotRepository();
    when(() => mockService.get(_plotId))
        .thenAnswer((_) async => _seedPlot());
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_seedPlot()]);
    // Repository stubs for PlotsNotifier stream subscription + build().
    when(() => mockPlotRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value([_seedPlot()]));
    when(() => mockPlotRepo.listByFarm(any()))
        .thenAnswer((_) async => [_seedPlot()]);
  });

  Widget wrap() => ProviderScope(
        overrides: [
          plotServiceProvider.overrideWithValue(mockService),
          plotRepositoryProvider.overrideWithValue(mockPlotRepo),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      );

  testWidgets('prefills the form with the loaded plot values', (tester) async {
    // Arrange + Act
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Assert — the three text fields show the loaded plot values (each text
    // appears exactly once in the form body).
    expect(find.text('Lote Norte'), findsOneWidget);
    expect(find.text('Trinitario'), findsOneWidget);
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('Editar lote'), findsOneWidget);
  });

  testWidgets('submitting calls update with the edited values', (tester) async {
    // Arrange — stub repo update; post-update refresh returns updated plot.
    when(() => mockPlotRepo.update(
          any(),
          name: any(named: 'name'),
          cropType: any(named: 'cropType'),
          status: any(named: 'status'),
          variety: any(named: 'variety'),
          areaHectares: any(named: 'areaHectares'),
        )).thenAnswer((_) async => _seedPlot().copyWith(name: 'Lote Sur'));
    when(() => mockPlotRepo.listByFarm(any()))
        .thenAnswer((_) async => [_seedPlot().copyWith(name: 'Lote Sur')]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Act — edit the name field (first TextFormField in the form) then submit.
    await tester.enterText(
      find.byType(TextFormField).first,
      'Lote Sur',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
    await tester.pumpAndSettle();

    // Assert — repo update called with edited name; snackbar shown.
    verify(() => mockPlotRepo.update(
          any(),
          name: 'Lote Sur',
          cropType: 'cacao',
          status: PlotStatus.growing,
          variety: 'Trinitario',
          areaHectares: 4.2,
        )).called(1);
    expect(find.text('Lote actualizado'), findsOneWidget);
  });
}
