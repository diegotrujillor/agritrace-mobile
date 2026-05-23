// Widget tests for the activity edit screen (CU-16).
//
// Verifies that:
//   1. The shared ActivityForm is prefilled from the loaded activity
//      (type, occurred-on date, description, photoUrl).
//   2. Submitting "Guardar cambios" calls ActivityService.update with the
//      edited values + shows the "Actividad actualizada" snackbar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/providers/activities_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/repositories/activity_repository.dart';
import 'package:agritrace_mobile/screens/activities/activity_edit_screen.dart';
import 'package:agritrace_mobile/services/activity_service.dart';

class _MockActivityService extends Mock implements ActivityService {}

class _MockActivityRepository extends Mock implements ActivityRepository {}

const _plotId = 'plot-1';
const _activityId = 'act-1';

Activity _seedActivity() => Activity(
      id: _activityId,
      plotId: _plotId,
      type: ActivityType.fertilization,
      // UTC to keep the formatted-date assertion deterministic regardless of
      // the test runner's local timezone.
      occurredAt: DateTime.utc(2026, 3, 15),
      createdAt: DateTime.utc(2026, 3, 15, 10),
      description: 'Aplicación NPK 15-15-15',
      photoUrl: 'https://example.com/photo.jpg',
    );

GoRouter _router() => GoRouter(
      initialLocation: '/activities/$_activityId/edit',
      routes: [
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
    registerFallbackValue(_seedActivity());
  });

  late _MockActivityService mockService;
  late _MockActivityRepository mockActivityRepo;

  setUp(() {
    mockService = _MockActivityService();
    mockActivityRepo = _MockActivityRepository();
    when(() => mockService.get(_activityId))
        .thenAnswer((_) async => _seedActivity());
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_seedActivity()]);
    // Repository stubs for ActivitiesNotifier stream subscription + build().
    when(() => mockActivityRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value([_seedActivity()]));
    when(() => mockActivityRepo.listByPlot(any()))
        .thenAnswer((_) async => [_seedActivity()]);
  });

  Widget wrap() => ProviderScope(
        overrides: [
          activityServiceProvider.overrideWithValue(mockService),
          activityRepositoryProvider.overrideWithValue(mockActivityRepo),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      );

  testWidgets(
    'prefills the form with the loaded activity values',
    (tester) async {
      // Arrange + Act
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Assert — AppBar + prefilled fields.
      expect(find.text('Editar actividad'), findsOneWidget);
      // Type dropdown shows the loaded type label.
      expect(find.text('Fertilización'), findsOneWidget);
      // Description field shows the stored note.
      expect(find.text('Aplicación NPK 15-15-15'), findsOneWidget);
      // v1.9.0 — the photo URL is no longer a TextField; the existing URL
      // is rendered as a thumbnail (Image.network), and the controls now
      // include the "Foto (opcional)" label plus the camera/gallery
      // buttons. Assert the label is visible instead of the raw URL.
      expect(find.text('Foto (opcional)'), findsOneWidget);
      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Galería'), findsOneWidget);
      // The submit button reads "Guardar cambios" in edit mode (not
      // "Registrar actividad").
      expect(
        find.widgetWithText(ElevatedButton, 'Guardar cambios'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submitting calls update with the edited values and shows snackbar',
    (tester) async {
      // Arrange — stub the repo update so the form can submit successfully.
      when(() => mockActivityRepo.update(
            any(),
            type: any(named: 'type'),
            occurredAt: any(named: 'occurredAt'),
            description: any(named: 'description'),
            photoUrl: any(named: 'photoUrl'),
          )).thenAnswer((_) async => _seedActivity().copyWith(
            description: 'Aplicación NPK 20-20-20',
          ));
      when(() => mockActivityRepo.listByPlot(any())).thenAnswer((_) async =>
          [_seedActivity().copyWith(description: 'Aplicación NPK 20-20-20')]);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Act — edit the description (the only TextFormField on the form
      // post-v1.9.0; the photo URL text input was replaced with the
      // image-picker section).
      await tester.enterText(
        find.byType(TextFormField).first,
        'Aplicación NPK 20-20-20',
      );
      // Scroll the submit button into view: with the photo section
      // injected above it, the default 800×600 test viewport pushes the
      // button slightly off-screen.
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Guardar cambios'),
      );
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
      await tester.pumpAndSettle();

      // Assert — repo update called with the edited description;
      // original type/occurredAt/photoUrl preserved (the form caches the
      // initial photoUrl as the "last uploaded" value when no new photo
      // is picked).
      verify(() => mockActivityRepo.update(
            any(),
            type: ActivityType.fertilization,
            occurredAt: DateTime.utc(2026, 3, 15),
            description: 'Aplicación NPK 20-20-20',
            photoUrl: 'https://example.com/photo.jpg',
          )).called(1);
      expect(find.text('Actividad actualizada'), findsOneWidget);
    },
  );
}
