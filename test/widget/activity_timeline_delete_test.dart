// Widget tests for the activity timeline long-press → "Editar / Eliminar"
// contextual sheet (CU-17).
//
// Verifies that:
//   1. Long-pressing an activity row opens a bottom sheet with two entries
//      (Editar + Eliminar).
//   2. Tapping Eliminar opens the destructive confirmation dialog with the
//      "no se puede deshacer" body.
//   3. Confirming calls ActivityService.delete with the right id.
//   4. Cancelar does NOT call delete.

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
import 'package:agritrace_mobile/screens/activities/activity_timeline_screen.dart';
import 'package:agritrace_mobile/services/activity_service.dart';
import 'package:agritrace_mobile/services/plot_service.dart';

class _MockActivityService extends Mock implements ActivityService {}

class _MockPlotService extends Mock implements PlotService {}

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _MockPlotRepository extends Mock implements PlotRepository {}

const _farmId = 'farm-1';
const _plotId = 'plot-1';
const _activityId = 'act-1';

Plot _seedPlot() => Plot(
      id: _plotId,
      farmId: _farmId,
      name: 'Lote Norte',
      cropType: 'cacao',
      status: PlotStatus.growing,
      createdAt: DateTime.utc(2026, 2, 1),
    );

Activity _seedActivity() => Activity(
      id: _activityId,
      plotId: _plotId,
      type: ActivityType.harvest,
      occurredAt: DateTime.utc(2026, 3, 20),
      createdAt: DateTime.utc(2026, 3, 20, 8),
      description: 'Cosecha matutina',
    );

GoRouter _router() => GoRouter(
      initialLocation: '/plots/$_plotId/activities',
      routes: [
        GoRoute(
          path: '/plots/:plotId/activities',
          builder: (_, state) => ActivityTimelineScreen(
            plotId: state.pathParameters['plotId']!,
          ),
        ),
        // Landing route the "Editar" entry pushes to.
        GoRoute(
          path: '/activities/:id/edit',
          builder: (_, state) => Scaffold(
            body: Text('EDIT-${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(ActivityType.other);
    registerFallbackValue(DateTime.utc(2026));
  });

  late _MockActivityService mockActivityService;
  late _MockPlotService mockPlotService;
  late _MockActivityRepository mockActivityRepo;
  late _MockPlotRepository mockPlotRepo;

  setUp(() {
    mockActivityService = _MockActivityService();
    mockPlotService = _MockPlotService();
    mockActivityRepo = _MockActivityRepository();
    mockPlotRepo = _MockPlotRepository();
    when(() => mockPlotService.get(_plotId))
        .thenAnswer((_) async => _seedPlot());
    when(() => mockActivityService.listByPlot(_plotId))
        .thenAnswer((_) async => [_seedActivity()]);
    // Repository stubs used by notifiers' stream subscriptions + build().
    when(() => mockActivityRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value([_seedActivity()]));
    when(() => mockActivityRepo.listByPlot(any()))
        .thenAnswer((_) async => [_seedActivity()]);
    when(() => mockPlotRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value([_seedPlot()]));
    when(() => mockPlotRepo.listByFarm(any()))
        .thenAnswer((_) async => [_seedPlot()]);
  });

  Widget wrap() => ProviderScope(
        overrides: [
          activityServiceProvider.overrideWithValue(mockActivityService),
          plotServiceProvider.overrideWithValue(mockPlotService),
          activityRepositoryProvider.overrideWithValue(mockActivityRepo),
          plotRepositoryProvider.overrideWithValue(mockPlotRepo),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      );

  testWidgets(
    'long-press → bottom sheet → Eliminar → confirm calls delete',
    (tester) async {
      // Arrange — stub repo delete. Initial build shows the seeded activity.
      when(() => mockActivityRepo.delete(_activityId))
          .thenAnswer((_) async {});

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Post-delete refresh returns empty list.
      when(() => mockActivityRepo.listByPlot(any()))
          .thenAnswer((_) async => <Activity>[]);

      // Act — long-press the activity row (matched by its type label).
      await tester.longPress(find.text('Cosecha'));
      await tester.pumpAndSettle();

      // Assert — bottom sheet shows Editar + Eliminar.
      expect(find.widgetWithText(ListTile, 'Editar'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Eliminar'), findsOneWidget);

      // Tap Eliminar — opens confirmation dialog.
      await tester.tap(find.widgetWithText(ListTile, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta actividad?'), findsOneWidget);
      expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Confirm — tap the red Eliminar button inside the dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      // Assert — repo called with the right id + success snackbar shown.
      verify(() => mockActivityRepo.delete(_activityId)).called(1);
      expect(find.text('Actividad eliminada'), findsOneWidget);
    },
  );

  testWidgets(
    'long-press → Editar pushes the edit route',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Cosecha'));
      await tester.pumpAndSettle();

      // Tap Editar — should close the sheet and navigate to the edit route.
      await tester.tap(find.widgetWithText(ListTile, 'Editar'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT-$_activityId'), findsOneWidget);
      verifyNever(() => mockActivityRepo.delete(any()));
    },
  );

  testWidgets(
    'long-press → Eliminar → Cancelar does not call delete',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Cosecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Eliminar'));
      await tester.pumpAndSettle();

      // Tap Cancelar.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => mockActivityRepo.delete(any()));
      // Still on the timeline.
      expect(find.text('Cosecha'), findsOneWidget);
    },
  );
}
