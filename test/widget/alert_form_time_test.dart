// Widget tests for the reminder time picker on `alert_form_screen` (CU-18).
//
// v1.12.1 — the form used to offer only a date picker, and
// `showDatePicker` returns midnight, so picking "tomorrow" scheduled the
// notification for 00:00. The form now has a separate time field
// (default 7:00 a. m.) and keeps the time when the date changes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:agritrace_mobile/models/alert.dart';
import 'package:agritrace_mobile/providers/alerts_provider.dart';
import 'package:agritrace_mobile/screens/alerts/alert_form_screen.dart';
import 'package:agritrace_mobile/utils/date_format.dart';
import 'package:agritrace_mobile/utils/reminder_schedule.dart';

/// Captures `createReminder` arguments without touching Drift or the API.
class _FakeAlertsNotifier extends AlertsNotifier {
  DateTime? scheduledFor;
  String? title;

  @override
  Future<List<Alert>> build() async => const [];

  @override
  Future<void> createReminder({
    required String title,
    required DateTime scheduledFor,
    String? body,
    String? plotId,
  }) async {
    this.title = title;
    this.scheduledFor = scheduledFor;
  }
}

Future<_FakeAlertsNotifier> _pumpForm(WidgetTester tester) async {
  final notifier = _FakeAlertsNotifier();
  final router = GoRouter(
    initialLocation: '/new',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('alerts list')),
      GoRoute(path: '/new', builder: (_, __) => const AlertFormScreen()),
    ],
  );
  // Start on the list so `context.pop()` after saving has somewhere to go.
  router.go('/');
  unawaited(router.push('/new'));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [alertsProvider.overrideWith(() => notifier)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets('shows a time field defaulting to 7:00 a. m. tomorrow',
      (tester) async {
    // Arrange
    final expected = defaultReminderDateTime(DateTime.now());

    // Act
    await _pumpForm(tester);

    // Assert
    expect(find.text('Hora del recordatorio'), findsOneWidget);
    expect(find.text('7:00 a. m.'), findsOneWidget);
    expect(find.text(formatLocalDate(expected)), findsOneWidget);
  });

  testWidgets('tapping the time field opens the time picker', (tester) async {
    await _pumpForm(tester);

    await tester.tap(find.text('7:00 a. m.'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets('saving sends tomorrow at 7:00 local time, not midnight',
      (tester) async {
    // Arrange
    final notifier = await _pumpForm(tester);
    final expected = defaultReminderDateTime(DateTime.now());

    // Act
    await tester.enterText(find.byType(TextFormField).first, 'Regar lote');
    await tester.tap(find.text('Crear recordatorio'));
    await tester.pumpAndSettle();

    // Assert
    expect(notifier.title, 'Regar lote');
    expect(notifier.scheduledFor, expected);
    expect(notifier.scheduledFor!.hour, kDefaultReminderHour);
  });
}
