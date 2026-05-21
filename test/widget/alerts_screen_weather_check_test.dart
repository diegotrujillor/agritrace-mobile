// Widget tests for the manual weather-check trigger on `alerts_screen`
// (CU-19).
//
// Verifies that:
//   1. Tapping the "Actualizar clima" AppBar action walks farms → plots and
//      calls `AlertService.checkWeather` once per plot.
//   2. Happy path with 2 new alerts shows the spinner during flight and ends
//      with a "Clima actualizado · 2 alertas nuevas" snackbar; the list
//      refreshes via `AlertService.list()` being called a second time.
//   3. Error path surfaces the red "No se pudo chequear el clima" snackbar
//      and does NOT clear the existing alert list.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/alert.dart';
import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/alerts_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/providers/farms_provider.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/repositories/alert_repository.dart';
import 'package:agritrace_mobile/repositories/farm_repository.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/screens/alerts/alerts_screen.dart';
import 'package:agritrace_mobile/services/alert_service.dart';
import 'package:agritrace_mobile/services/farm_service.dart';
import 'package:agritrace_mobile/services/plot_service.dart';
import 'package:agritrace_mobile/utils/constants.dart';

class _MockAlertService extends Mock implements AlertService {}

class _MockFarmService extends Mock implements FarmService {}

class _MockPlotService extends Mock implements PlotService {}

class _MockAlertRepository extends Mock implements AlertRepository {}

class _MockFarmRepository extends Mock implements FarmRepository {}

class _MockPlotRepository extends Mock implements PlotRepository {}

Farm _farm(String id) => Farm(
      id: id,
      name: 'Finca $id',
      cropType: 'cacao',
      areaHectares: 5.0,
      createdAt: DateTime.utc(2026, 1, 1),
    );

Plot _plot(String id, String farmId) => Plot(
      id: id,
      farmId: farmId,
      name: 'Lote $id',
      cropType: 'cacao',
      status: PlotStatus.growing,
      createdAt: DateTime.utc(2026, 1, 2),
    );

Alert _alert(String id) => Alert(
      id: id,
      type: AlertType.weather,
      severity: AlertSeverity.warning,
      title: 'Lluvia fuerte mañana',
      status: AlertStatus.pending,
      createdAt: DateTime.utc(2026, 5, 19),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AlertStatus.pending);
    registerFallbackValue(AlertType.reminder);
  });

  late _MockAlertService mockAlerts;
  late _MockFarmService mockFarms;
  late _MockPlotService mockPlots;
  late _MockAlertRepository mockAlertRepo;
  late _MockFarmRepository mockFarmRepo;
  late _MockPlotRepository mockPlotRepo;

  setUp(() {
    mockAlerts = _MockAlertService();
    mockFarms = _MockFarmService();
    mockPlots = _MockPlotService();
    mockAlertRepo = _MockAlertRepository();
    mockFarmRepo = _MockFarmRepository();
    mockPlotRepo = _MockPlotRepository();

    // Default: the user owns one farm with two plots.
    when(() => mockFarms.list()).thenAnswer((_) async => [_farm('farm-1')]);
    when(() => mockPlots.listByFarm('farm-1')).thenAnswer(
      (_) async => [_plot('plot-1', 'farm-1'), _plot('plot-2', 'farm-1')],
    );
    // Initial alerts list — empty until weather check raises something.
    when(() => mockAlerts.list(
          status: any(named: 'status'),
          type: any(named: 'type'),
        )).thenAnswer((_) async => <Alert>[]);
    // Repository stubs for the notifiers' stream subscriptions + build().
    when(() => mockAlertRepo.watchAll())
        .thenAnswer((_) => Stream.value(<Alert>[]));
    when(() => mockFarmRepo.watchAll())
        .thenAnswer((_) => Stream.value([_farm('farm-1')]));
    when(() => mockFarmRepo.listAll())
        .thenAnswer((_) async => [_farm('farm-1')]);
    when(() => mockPlotRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value(
              [_plot('plot-1', 'farm-1'), _plot('plot-2', 'farm-1')],
            ));
    when(() => mockPlotRepo.listByFarm(any())).thenAnswer((_) async =>
        [_plot('plot-1', 'farm-1'), _plot('plot-2', 'farm-1')]);
  });

  GoRouter router() => GoRouter(
        initialLocation: '/alerts',
        routes: [
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
          // Dashboard route exists so the back arrow on the AppBar can navigate.
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const Scaffold(body: Text('DASH')),
          ),
        ],
      );

  Widget wrap() => ProviderScope(
        overrides: [
          alertServiceProvider.overrideWithValue(mockAlerts),
          farmServiceProvider.overrideWithValue(mockFarms),
          plotServiceProvider.overrideWithValue(mockPlots),
          alertRepositoryProvider.overrideWithValue(mockAlertRepo),
          farmRepositoryProvider.overrideWithValue(mockFarmRepo),
          plotRepositoryProvider.overrideWithValue(mockPlotRepo),
        ],
        child: MaterialApp.router(routerConfig: router()),
      );

  testWidgets(
    'tapping "Actualizar clima" calls checkWeather once per plot',
    (tester) async {
      // Arrange — provider returns no actionable alert.
      when(() => mockAlerts.checkWeather(any())).thenAnswer(
        (_) async => const WeatherCheckResult(provider: 'stub'),
      );

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Act — tap the AppBar action.
      await tester.tap(find.byTooltip('Actualizar clima'));
      await tester.pumpAndSettle();

      // Assert — one call per plot.
      verify(() => mockAlerts.checkWeather('plot-1')).called(1);
      verify(() => mockAlerts.checkWeather('plot-2')).called(1);
    },
  );

  testWidgets(
    'happy path · 2 new alerts → spinner shown during call → snackbar with count',
    (tester) async {
      // Arrange — both plots raise a weather alert. Use a single completer
      // that gates all checkWeather calls; resolve it later so the spinner is
      // observable mid-flight.
      final gate = Completer<void>();
      when(() => mockAlerts.checkWeather(any())).thenAnswer((_) async {
        await gate.future;
        return WeatherCheckResult(provider: 'stub', alert: _alert('a-x'));
      });
      when(() => mockAlertRepo.upsertFromServer(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Act — tap and pump enough frames so farms/plots futures resolve and
      // the first checkWeather call is awaiting at the gate.
      await tester.tap(find.byTooltip('Actualizar clima'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Assert — spinner shown, icon hidden.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byTooltip('Actualizar clima'), findsNothing);

      // Swap the repo stream mock so the post-check refresh returns 2 alerts.
      when(() => mockAlertRepo.watchAll())
          .thenAnswer((_) => Stream.value([_alert('a-1'), _alert('a-2')]));

      // Open the gate — all in-flight checkWeather calls resolve in order.
      gate.complete();
      // Discrete pumps to let the async chain (refresh → showSnackBar →
      // entrance animation) play out without entering the SnackBar's 4s
      // auto-dismiss timer wait that would trip pumpAndSettle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Assert — snackbar with count, icon back, repo received 2 upserts.
      expect(
        find.text('Clima actualizado · 2 alertas nuevas'),
        findsOneWidget,
      );
      expect(find.byTooltip('Actualizar clima'), findsOneWidget);
      verify(() => mockAlertRepo.upsertFromServer(any())).called(2);
    },
  );

  testWidgets(
    'error path · service throws → red snackbar, list not cleared',
    (tester) async {
      // Arrange — seed the repo with an existing alert and make the check throw.
      when(() => mockAlertRepo.watchAll())
          .thenAnswer((_) => Stream.value([_alert('seed-1')]));
      when(() => mockAlerts.checkWeather(any()))
          .thenThrow(Exception('network down'));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('Lluvia fuerte mañana'), findsOneWidget);

      // Act — tap.
      await tester.tap(find.byTooltip('Actualizar clima'));
      // Discrete pumps — pumpAndSettle would wait on the SnackBar 4s timer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert — red snackbar shown, existing alert still present.
      expect(
        find.text('No se pudo chequear el clima. Intenta más tarde.'),
        findsOneWidget,
      );
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, AppColors.error);
      expect(find.text('Lluvia fuerte mañana'), findsOneWidget);
    },
  );
}
