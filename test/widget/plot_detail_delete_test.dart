// Widget tests for the plot detail screen overflow menu — Eliminar flow
// (CU-13).
//
// Verifies that:
//   1. The overflow menu offers an "Eliminar" entry.
//   2. Tapping it opens the confirmation dialog with the cascade warning.
//   3. Confirming calls PlotService.delete with the right id and navigates
//      back to the parent farm detail route.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/activities_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/repositories/activity_repository.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/screens/plots/plot_detail_screen.dart';
import 'package:agritrace_mobile/services/activity_service.dart';
import 'package:agritrace_mobile/services/plot_service.dart';

class _MockPlotService extends Mock implements PlotService {}

class _MockActivityService extends Mock implements ActivityService {}

class _MockPlotRepository extends Mock implements PlotRepository {}

class _MockActivityRepository extends Mock implements ActivityRepository {}

const _farmId = 'farm-1';
const _plotId = 'plot-1';

Plot _seedPlot() => Plot(
      id: _plotId,
      farmId: _farmId,
      name: 'Lote Norte',
      cropType: 'cacao',
      status: PlotStatus.growing,
      createdAt: DateTime.utc(2026, 2, 1),
    );

GoRouter _router() => GoRouter(
      initialLocation: '/plots/$_plotId',
      routes: [
        GoRoute(
          path: '/plots/:id',
          builder: (_, state) =>
              PlotDetailScreen(plotId: state.pathParameters['id']!),
        ),
        // Parent farm detail route the delete flow navigates back to.
        GoRoute(
          path: '/farms/:id',
          builder: (_, state) => Scaffold(
            body: Text('FARM-${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(PlotStatus.planning);
  });

  late _MockPlotService mockPlotService;
  late _MockActivityService mockActivityService;
  late _MockPlotRepository mockPlotRepo;
  late _MockActivityRepository mockActivityRepo;

  setUp(() {
    mockPlotService = _MockPlotService();
    mockActivityService = _MockActivityService();
    mockPlotRepo = _MockPlotRepository();
    mockActivityRepo = _MockActivityRepository();
    when(() => mockPlotService.get(_plotId))
        .thenAnswer((_) async => _seedPlot());
    when(() => mockPlotService.listByFarm(_farmId))
        .thenAnswer((_) async => [_seedPlot()]);
    when(() => mockActivityService.listByPlot(_plotId))
        .thenAnswer((_) async => <Activity>[]);
    // Repository stubs used by the notifiers' stream subscriptions + build().
    when(() => mockPlotRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value([_seedPlot()]));
    when(() => mockPlotRepo.listByFarm(any()))
        .thenAnswer((_) async => [_seedPlot()]);
    when(() => mockActivityRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value(<Activity>[]));
    when(() => mockActivityRepo.listByPlot(any()))
        .thenAnswer((_) async => <Activity>[]);
    // v1.9.0 — plotProvider is now local-first; stub the repo lookup so
    // the detail screen resolves without hitting the (mocked-but-unstubbed)
    // service path.
    when(() => mockPlotRepo.getById(_plotId))
        .thenAnswer((_) async => _seedPlot());
  });

  Widget wrap() => ProviderScope(
        overrides: [
          plotServiceProvider.overrideWithValue(mockPlotService),
          activityServiceProvider.overrideWithValue(mockActivityService),
          plotRepositoryProvider.overrideWithValue(mockPlotRepo),
          activityRepositoryProvider.overrideWithValue(mockActivityRepo),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      );

  testWidgets(
    'overflow menu → Eliminar → confirm calls delete and navigates back',
    (tester) async {
      // Arrange
      when(() => mockPlotRepo.delete(_plotId)).thenAnswer((_) async {});
      // After delete, list refetch returns an empty list (plot is gone).
      when(() => mockPlotRepo.listByFarm(any()))
          .thenAnswer((_) async => <Plot>[]);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Act — open overflow menu.
      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);

      // Tap Eliminar — opens confirmation dialog.
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar lote?'), findsOneWidget);
      expect(
        find.textContaining('Las actividades asociadas también se eliminarán'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);

      // Confirm by tapping the red Eliminar button inside the dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      // Assert — repo called with the right id + back-nav landed on farm.
      verify(() => mockPlotRepo.delete(_plotId)).called(1);
      expect(find.text('FARM-$_farmId'), findsOneWidget);
    },
  );

  testWidgets(
    'overflow menu → Eliminar → Cancelar does not call delete',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      // Tap Cancelar.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => mockPlotRepo.delete(any()));
      // Still on the plot detail screen — no nav happened.
      expect(find.text('Lote Norte'), findsWidgets);
    },
  );
}
