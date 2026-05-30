// Regression tests for v1.9.5 — every form screen must render exactly
// ONE `AppLogoMark`. In v1.9.4 we added a top-centered 80 px logo header
// to the form screens but kept the previous bottom-left logo, which left
// the producer staring at two identical marks on the same view. v1.9.5
// removes the bottom-left overlay on the three create screens
// (`Registrar actividad`, `Agregar lote`, `Registrar finca`); the two
// edit screens (`Editar lote`, `Editar actividad`) already shipped with
// only the top header in v1.9.4 and stay that way.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/activities_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/providers/farms_provider.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/repositories/activity_repository.dart';
import 'package:agritrace_mobile/repositories/farm_repository.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/screens/activities/activity_edit_screen.dart';
import 'package:agritrace_mobile/screens/activities/activity_form_screen.dart';
import 'package:agritrace_mobile/screens/farms/farm_form_screen.dart';
import 'package:agritrace_mobile/screens/plots/plot_edit_screen.dart';
import 'package:agritrace_mobile/screens/plots/plot_form_screen.dart';
import 'package:agritrace_mobile/services/activity_service.dart';
import 'package:agritrace_mobile/services/farm_service.dart';
import 'package:agritrace_mobile/services/plot_service.dart';
import 'package:agritrace_mobile/widgets/common/app_logo_mark.dart';

class _MockPlotService extends Mock implements PlotService {}

class _MockPlotRepository extends Mock implements PlotRepository {}

class _MockActivityService extends Mock implements ActivityService {}

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _MockFarmService extends Mock implements FarmService {}

class _MockFarmRepository extends Mock implements FarmRepository {}

const _farmId = 'farm-1';
const _plotId = 'plot-1';
const _activityId = 'activity-1';

Plot _seedPlot() => Plot(
      id: _plotId,
      farmId: _farmId,
      name: 'Lote Norte',
      cropType: 'cacao',
      status: PlotStatus.growing,
      variety: 'Trinitario',
      areaHectares: 4.2,
      createdAt: DateTime.utc(2026, 5, 1),
    );

Activity _seedActivity() => Activity(
      id: _activityId,
      plotId: _plotId,
      type: ActivityType.fertilization,
      occurredAt: DateTime.utc(2026, 5, 10),
      description: 'Aplicación de compost',
      createdAt: DateTime.utc(2026, 5, 10),
    );

Widget _host({
  required Widget child,
  required List<Override> overrides,
  required String path,
}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, __) => child)],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_seedPlot());
    registerFallbackValue(_seedActivity());
    registerFallbackValue(PlotStatus.planning);
    registerFallbackValue(ActivityType.other);
  });

  testWidgets(
      'activity_form_screen (Registrar actividad) renders exactly one AppLogoMark',
      (tester) async {
    final mockService = _MockActivityService();
    final mockRepo = _MockActivityRepository();
    when(() => mockService.listByPlot(_plotId)).thenAnswer((_) async => []);
    when(() => mockRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value(<Activity>[]));
    when(() => mockRepo.listByPlot(any()))
        .thenAnswer((_) async => <Activity>[]);

    await tester.pumpWidget(_host(
      child: const ActivityFormScreen(plotId: _plotId),
      overrides: [
        activityServiceProvider.overrideWithValue(mockService),
        activityRepositoryProvider.overrideWithValue(mockRepo),
      ],
      path: '/activities/new',
    ));
    await tester.pump();

    expect(find.byType(AppLogoMark), findsOneWidget);
  });

  testWidgets(
      'activity_edit_screen (Editar actividad) renders exactly one AppLogoMark',
      (tester) async {
    final mockService = _MockActivityService();
    final mockRepo = _MockActivityRepository();
    when(() => mockService.get(_activityId))
        .thenAnswer((_) async => _seedActivity());
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_seedActivity()]);
    when(() => mockRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value([_seedActivity()]));
    when(() => mockRepo.listByPlot(any()))
        .thenAnswer((_) async => [_seedActivity()]);
    // v1.10.1 fix #34: `activityProvider(id)` is local-first; getById
    // must resolve before the screen renders.
    when(() => mockRepo.getById(any()))
        .thenAnswer((_) async => _seedActivity());

    await tester.pumpWidget(_host(
      child: const ActivityEditScreen(activityId: _activityId),
      overrides: [
        activityServiceProvider.overrideWithValue(mockService),
        activityRepositoryProvider.overrideWithValue(mockRepo),
      ],
      path: '/activities/edit',
    ));
    // Two pumps so the FutureProvider resolves and the body switches from
    // CircularProgressIndicator → form.
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppLogoMark), findsOneWidget);
  });

  testWidgets('plot_form_screen (Agregar lote) renders exactly one AppLogoMark',
      (tester) async {
    final mockService = _MockPlotService();
    final mockRepo = _MockPlotRepository();
    when(() => mockService.listByFarm(_farmId)).thenAnswer((_) async => []);
    when(() => mockRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value(<Plot>[]));
    when(() => mockRepo.listByFarm(any())).thenAnswer((_) async => <Plot>[]);

    await tester.pumpWidget(_host(
      child: const PlotFormScreen(farmId: _farmId),
      overrides: [
        plotServiceProvider.overrideWithValue(mockService),
        plotRepositoryProvider.overrideWithValue(mockRepo),
      ],
      path: '/plots/new',
    ));
    await tester.pump();

    expect(find.byType(AppLogoMark), findsOneWidget);
  });

  testWidgets('plot_edit_screen (Editar lote) renders exactly one AppLogoMark',
      (tester) async {
    final mockService = _MockPlotService();
    final mockRepo = _MockPlotRepository();
    when(() => mockService.get(_plotId)).thenAnswer((_) async => _seedPlot());
    when(() => mockService.listByFarm(_farmId))
        .thenAnswer((_) async => [_seedPlot()]);
    when(() => mockRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value([_seedPlot()]));
    when(() => mockRepo.listByFarm(any()))
        .thenAnswer((_) async => [_seedPlot()]);
    when(() => mockRepo.getById(_plotId)).thenAnswer((_) async => _seedPlot());

    await tester.pumpWidget(_host(
      child: const PlotEditScreen(plotId: _plotId),
      overrides: [
        plotServiceProvider.overrideWithValue(mockService),
        plotRepositoryProvider.overrideWithValue(mockRepo),
      ],
      path: '/plots/edit',
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppLogoMark), findsOneWidget);
  });

  testWidgets(
      'farm_form_screen (Registrar finca) renders exactly one AppLogoMark',
      (tester) async {
    final mockService = _MockFarmService();
    final mockRepo = _MockFarmRepository();
    when(() => mockService.list()).thenAnswer((_) async => []);
    when(() => mockRepo.watchAll()).thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.listAll()).thenAnswer((_) async => []);

    await tester.pumpWidget(_host(
      child: const FarmFormScreen(),
      overrides: [
        farmServiceProvider.overrideWithValue(mockService),
        farmRepositoryProvider.overrideWithValue(mockRepo),
      ],
      path: '/farms/new',
    ));
    await tester.pump();

    expect(find.byType(AppLogoMark), findsOneWidget);
  });
}
