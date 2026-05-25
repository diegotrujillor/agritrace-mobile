// Widget tests for the v1.9.6 soft duplicate-warning dialog on
// `Registrar actividad` (CU-15 hardening).
//
// Scenarios (mapped to the task spec):
//   1. Siembra duplicate same day same plot → dialog → Cancelar →
//      activity NOT saved.
//   2. Siembra duplicate same day same plot → dialog → Sí, continuar →
//      activity saved.
//   3. Siembra different day same plot → NO dialog, activity saved.
//   4. Siembra same day different plot → NO dialog, activity saved.
//   5. Fertilización duplicate same day same plot → NO dialog
//      (only the types in `kDuplicateWarnActivityTypes` warn).
//   6. Editing an existing Siembra (separate edit screen path) → NO
//      dialog (edit screen never instantiates `ActivityFormScreen`).
//
// All paths exercise the real `ActivityFormScreen` and the real
// `ActivitiesNotifier` against a mocked `ActivityRepository` (mocktail) —
// matches the pattern already used in `activity_edit_screen_test.dart`
// and `activities_provider_test.dart`. Date pickers are NOT opened —
// the form's default `_occurredAt` is `DateTime.now()` and the seeded
// duplicate uses the same wall-clock day, so the year/month/day
// comparison resolves to "today".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/providers/activities_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/repositories/activity_repository.dart';
import 'package:agritrace_mobile/screens/activities/activity_form_screen.dart';
import 'package:agritrace_mobile/screens/activities/activity_edit_screen.dart';
import 'package:agritrace_mobile/services/activity_service.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _MockActivityService extends Mock implements ActivityService {}

const _plotId = 'plot-1';
const _otherPlotId = 'plot-2';

Activity _activity({
  String id = 'act-existing',
  ActivityType type = ActivityType.sowing,
  required DateTime occurredAt,
  String plotId = _plotId,
}) =>
    Activity(
      id: id,
      plotId: plotId,
      type: type,
      occurredAt: occurredAt,
      createdAt: occurredAt,
    );

GoRouter _router({required String startRoute}) => GoRouter(
      initialLocation: startRoute,
      routes: [
        GoRoute(
          path: '/plots/:plotId/activities/new',
          builder: (_, state) => ActivityFormScreen(
            plotId: state.pathParameters['plotId']!,
          ),
        ),
        GoRoute(
          path: '/activities/:id/edit',
          builder: (_, state) => ActivityEditScreen(
            activityId: state.pathParameters['id']!,
          ),
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
    registerFallbackValue(ActivityType.other);
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(
      _activity(occurredAt: DateTime.utc(2026)),
    );
  });

  late _MockActivityRepository mockRepo;
  late _MockActivityService mockService;
  // Stable "today" anchor (local) used everywhere we want the seeded
  // duplicate to match the form's default `_occurredAt`. Captured once
  // per test in `setUp` so the assertion windows are deterministic.
  late DateTime today;
  late DateTime yesterday;

  setUp(() {
    mockRepo = _MockActivityRepository();
    mockService = _MockActivityService();
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day, 9);
    yesterday = today.subtract(const Duration(days: 1));
  });

  Widget wrap({required String startRoute, required List<Activity> seeded}) {
    when(() => mockRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value(seeded));
    when(() => mockRepo.listByPlot(any()))
        .thenAnswer((_) async => seeded);
    when(() => mockRepo.create(
          plotId: any(named: 'plotId'),
          type: any(named: 'type'),
          occurredAt: any(named: 'occurredAt'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        )).thenAnswer((inv) async {
      final t = inv.namedArguments[const Symbol('type')] as ActivityType;
      final o =
          inv.namedArguments[const Symbol('occurredAt')] as DateTime;
      final p = inv.namedArguments[const Symbol('plotId')] as String;
      return _activity(
        id: 'act-new',
        type: t,
        occurredAt: o,
        plotId: p,
      );
    });
    when(() => mockService.get(any())).thenAnswer(
      (inv) async => seeded.firstWhere(
        (a) => a.id == inv.positionalArguments.first,
        orElse: () => seeded.first,
      ),
    );

    return ProviderScope(
      overrides: [
        activityRepositoryProvider.overrideWithValue(mockRepo),
        activityServiceProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp.router(routerConfig: _router(startRoute: startRoute)),
    );
  }

  // Submits the form using its current defaults (type=Siembra, date=today).
  // Used by every "type already correct" case so we don't fiddle with the
  // dropdown or date picker.
  //
  // NOTE: we `pump()` (not `pumpAndSettle()`) after the tap because when
  // the duplicate-warning dialog opens, the form's `onSubmit` future is
  // suspended on `await showDialog<bool>(…)` — `pumpAndSettle` would
  // time out waiting for that future to complete. `pump()` advances one
  // frame, which is enough for the dialog widget to mount and become
  // findable. A second `pump()` flushes the route transition animation.
  Future<void> tapRegister(WidgetTester tester) async {
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Registrar actividad'),
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Registrar actividad'),
    );
    // Allow the form's _submit() future to start + the dialog to mount.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Siembra duplicate same day same plot → Cancelar does NOT save',
    (tester) async {
      // Arrange — one existing Siembra today on this plot.
      await tester.pumpWidget(wrap(
        startRoute: '/plots/$_plotId/activities/new',
        seeded: [_activity(occurredAt: today)],
      ));
      await tester.pumpAndSettle();

      // Act — submit with defaults (Siembra + today).
      await tapRegister(tester);

      // Assert — dialog visible with the expected copy.
      expect(find.text('Ya registraste Siembra'), findsOneWidget);
      expect(find.textContaining('¿Continuar de todas formas?'), findsOneWidget);

      // Tap Cancelar. Use bounded pumps instead of pumpAndSettle: the
      // form keeps `_submitting=true` after onSubmit returns normally
      // (per the comment in ActivityForm._submit), so the spinner
      // animation never settles. A handful of frames is enough for the
      // dialog teardown + the early return.
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert — create NOT called.
      verifyNever(() => mockRepo.create(
            plotId: any(named: 'plotId'),
            type: any(named: 'type'),
            occurredAt: any(named: 'occurredAt'),
            description: any(named: 'description'),
            photoUrl: any(named: 'photoUrl'),
          ));
    },
  );

  testWidgets(
    'Siembra duplicate same day same plot → Sí, continuar DOES save',
    (tester) async {
      await tester.pumpWidget(wrap(
        startRoute: '/plots/$_plotId/activities/new',
        seeded: [_activity(occurredAt: today)],
      ));
      await tester.pumpAndSettle();

      await tapRegister(tester);

      expect(find.text('Ya registraste Siembra'), findsOneWidget);

      // Tap Sí, continuar.
      await tester.tap(find.widgetWithText(TextButton, 'Sí, continuar'));
      await tester.pumpAndSettle();

      // Assert — create called exactly once with Siembra.
      verify(() => mockRepo.create(
            plotId: _plotId,
            type: ActivityType.sowing,
            occurredAt: any(named: 'occurredAt'),
            description: null,
            photoUrl: null,
          )).called(1);
    },
  );

  testWidgets(
    'Siembra different day same plot → NO dialog, activity saved',
    (tester) async {
      // Arrange — existing Siembra is YESTERDAY, form default is today.
      await tester.pumpWidget(wrap(
        startRoute: '/plots/$_plotId/activities/new',
        seeded: [_activity(occurredAt: yesterday)],
      ));
      await tester.pumpAndSettle();

      await tapRegister(tester);

      // Assert — no dialog, create called.
      expect(find.text('Ya registraste Siembra'), findsNothing);
      verify(() => mockRepo.create(
            plotId: _plotId,
            type: ActivityType.sowing,
            occurredAt: any(named: 'occurredAt'),
            description: null,
            photoUrl: null,
          )).called(1);
    },
  );

  testWidgets(
    'Siembra same day different plot → NO dialog, activity saved',
    (tester) async {
      // Arrange — the seeded "duplicate" belongs to a DIFFERENT plot.
      // Because the family-scoped notifier only sees this plot's rows
      // (listByPlot is plot-scoped), the duplicate-detection query
      // returns an empty list and the form proceeds.
      when(() => mockRepo.listByPlot(_plotId))
          .thenAnswer((_) async => <Activity>[]);
      when(() => mockRepo.watchByPlot(_plotId))
          .thenAnswer((_) => Stream.value(<Activity>[]));
      // (The "other plot" row is never read because the notifier filters
      // by plot — but we stub it for completeness.)
      when(() => mockRepo.listByPlot(_otherPlotId)).thenAnswer(
          (_) async => [_activity(occurredAt: today, plotId: _otherPlotId)]);

      await tester.pumpWidget(wrap(
        startRoute: '/plots/$_plotId/activities/new',
        seeded: const <Activity>[],
      ));
      await tester.pumpAndSettle();

      await tapRegister(tester);

      expect(find.text('Ya registraste Siembra'), findsNothing);
      verify(() => mockRepo.create(
            plotId: _plotId,
            type: ActivityType.sowing,
            occurredAt: any(named: 'occurredAt'),
            description: null,
            photoUrl: null,
          )).called(1);
    },
  );

  testWidgets(
    'Fertilización duplicate same day same plot → NO dialog',
    (tester) async {
      // Arrange — existing Fertilización today on this plot.
      await tester.pumpWidget(wrap(
        startRoute: '/plots/$_plotId/activities/new',
        seeded: [
          _activity(type: ActivityType.fertilization, occurredAt: today),
        ],
      ));
      await tester.pumpAndSettle();

      // Act — change the type dropdown from Siembra to Fertilización so
      // the duplicate would semantically match if the warning fired.
      await tester.tap(find.text('Siembra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fertilización').last);
      await tester.pumpAndSettle();

      await tapRegister(tester);

      // Assert — no dialog (Fertilización is not in
      // `kDuplicateWarnActivityTypes`); create was called.
      expect(find.text('Ya registraste Fertilización'), findsNothing);
      verify(() => mockRepo.create(
            plotId: _plotId,
            type: ActivityType.fertilization,
            occurredAt: any(named: 'occurredAt'),
            description: null,
            photoUrl: null,
          )).called(1);
    },
  );

  testWidgets(
    'Editing an existing Siembra → NO dialog (edit screen path)',
    (tester) async {
      // Arrange — an existing Siembra today + we land on the EDIT screen
      // for it. The duplicate-warning hook lives in `ActivityFormScreen`
      // (create-only); `ActivityEditScreen` calls `updateActivity`, which
      // bypasses the create flow entirely. Saving from edit must not
      // surface the prompt even though a same-day same-plot Siembra
      // exists (it IS this row).
      final existing = _activity(occurredAt: today);
      when(() => mockRepo.update(
            any(),
            type: any(named: 'type'),
            occurredAt: any(named: 'occurredAt'),
            description: any(named: 'description'),
            photoUrl: any(named: 'photoUrl'),
          )).thenAnswer((_) async => existing);

      await tester.pumpWidget(wrap(
        startRoute: '/activities/${existing.id}/edit',
        seeded: [existing],
      ));
      await tester.pumpAndSettle();

      // Sanity — we're on the edit screen.
      expect(find.text('Editar actividad'), findsOneWidget);

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Guardar cambios'),
      );
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      // Assert — duplicate dialog never appeared; update was called once.
      expect(find.text('Ya registraste Siembra'), findsNothing);
      verify(() => mockRepo.update(
            any(),
            type: ActivityType.sowing,
            occurredAt: any(named: 'occurredAt'),
            description: any(named: 'description'),
            photoUrl: any(named: 'photoUrl'),
          )).called(1);
    },
  );
}
