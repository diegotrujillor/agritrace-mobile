// v1.9.8 — P3 fix. Regression test for the bottom-left logo alignment
// with the bottom-right FAB on the Dashboard and Vista finca screens.
//
// The v1.9.4 implementation pinned both at `bottom: 16` and ate the
// resulting 4 px center offset as "below the perceptual threshold". The
// pilot QA captures (#25, #26, #27) showed the offset was clearly
// visible on real devices. This file asserts that the logo and the FAB
// share a vertical center to within 2 px.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/providers/farms_provider.dart';
import 'package:agritrace_mobile/providers/plots_provider.dart';
import 'package:agritrace_mobile/repositories/farm_repository.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/screens/farms/dashboard_screen.dart';
import 'package:agritrace_mobile/screens/farms/farm_detail_screen.dart';
import 'package:agritrace_mobile/services/farm_service.dart';
import 'package:agritrace_mobile/services/plot_service.dart';
import 'package:agritrace_mobile/widgets/common/app_logo_mark.dart';

class _MockFarmService extends Mock implements FarmService {}

class _MockFarmRepository extends Mock implements FarmRepository {}

class _MockPlotService extends Mock implements PlotService {}

class _MockPlotRepository extends Mock implements PlotRepository {}

const _farmId = 'farm-1';

Farm _farm() => Farm(
      id: _farmId,
      name: 'Finca Las Mercedes',
      cropType: 'cacao',
      areaHectares: 6.5,
      createdAt: DateTime.utc(2026, 5, 1),
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
    registerFallbackValue(_farm());
  });

  testWidgets(
      'Dashboard: 64 px logo vertical center matches 56 px FAB center within 2 px',
      (tester) async {
    final mockFarmService = _MockFarmService();
    final mockFarmRepo = _MockFarmRepository();
    when(() => mockFarmRepo.listAll()).thenAnswer((_) async => <Farm>[]);
    when(() => mockFarmRepo.watchAll())
        .thenAnswer((_) => Stream.value(<Farm>[]));

    await tester.pumpWidget(_host(
      child: const DashboardScreen(),
      overrides: [
        farmServiceProvider.overrideWithValue(mockFarmService),
        farmRepositoryProvider.overrideWithValue(mockFarmRepo),
      ],
      path: '/dashboard',
    ));
    await tester.pumpAndSettle();

    final logoRect = tester.getRect(find.byType(AppLogoMark));
    final fabRect = tester.getRect(find.byType(FloatingActionButton));

    // 2 px tolerance — matches the perceptual threshold cited in the
    // v1.9.4 comment that we are explicitly tightening.
    expect(
      (logoRect.center.dy - fabRect.center.dy).abs(),
      lessThanOrEqualTo(2.0),
      reason: 'logo center.dy=${logoRect.center.dy}, '
          'fab center.dy=${fabRect.center.dy}',
    );
  });

  testWidgets(
      'Vista finca: 80 px logo vertical center matches extended FAB center within 2 px',
      (tester) async {
    final mockFarmService = _MockFarmService();
    final mockFarmRepo = _MockFarmRepository();
    final mockPlotService = _MockPlotService();
    final mockPlotRepo = _MockPlotRepository();

    when(() => mockFarmRepo.getById(_farmId)).thenAnswer((_) async => _farm());
    when(() => mockFarmRepo.listAll()).thenAnswer((_) async => [_farm()]);
    when(() => mockFarmRepo.watchAll())
        .thenAnswer((_) => Stream.value([_farm()]));
    when(() => mockPlotService.listByFarm(_farmId))
        .thenAnswer((_) async => <Plot>[]);
    when(() => mockPlotRepo.watchByFarm(any()))
        .thenAnswer((_) => Stream.value(<Plot>[]));
    when(() => mockPlotRepo.listByFarm(any()))
        .thenAnswer((_) async => <Plot>[]);

    await tester.pumpWidget(_host(
      child: const FarmDetailScreen(farmId: _farmId),
      overrides: [
        farmServiceProvider.overrideWithValue(mockFarmService),
        farmRepositoryProvider.overrideWithValue(mockFarmRepo),
        plotServiceProvider.overrideWithValue(mockPlotService),
        plotRepositoryProvider.overrideWithValue(mockPlotRepo),
      ],
      path: '/farms/$_farmId',
    ));
    await tester.pumpAndSettle();

    final logoRect = tester.getRect(find.byType(AppLogoMark));
    // Vista finca uses `FloatingActionButton.extended`; it still
    // resolves to a `FloatingActionButton` in the widget tree but the
    // height differs from the standard FAB. We measure the rendered
    // rect, not a hardcoded constant, so the assertion holds across
    // Material theme changes.
    final fabRect = tester.getRect(find.byType(FloatingActionButton));

    expect(
      (logoRect.center.dy - fabRect.center.dy).abs(),
      lessThanOrEqualTo(2.0),
      reason: 'logo center.dy=${logoRect.center.dy}, '
          'fab center.dy=${fabRect.center.dy}',
    );
  });
}
