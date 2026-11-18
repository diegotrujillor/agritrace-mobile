import 'dart:async';

import 'package:agritrace_mobile/models/alert.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/providers/reminder_notifications_provider.dart';
import 'package:agritrace_mobile/repositories/alert_repository.dart';
import 'package:agritrace_mobile/services/reminder_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

/// Records every gateway call so tests can assert the exact OS-level
/// effect of a sync (cancel + schedule) without the native plugin.
class FakeGateway implements NotificationGateway {
  final List<String> calls = [];
  final List<PlannedNotification> scheduled = [];
  bool throwOnSchedule = false;
  bool permissionResult = true;

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
    scheduled.clear();
  }

  @override
  Future<void> schedule(PlannedNotification n) async {
    if (throwOnSchedule) throw StateError('plugin unavailable');
    calls.add('schedule:${n.alertId}');
    scheduled.add(n);
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permissionResult;
  }
}

final _now = DateTime.utc(2026, 11, 18, 12);

Alert _alert(
  String id, {
  AlertType type = AlertType.reminder,
  AlertStatus status = AlertStatus.pending,
  DateTime? scheduledFor,
  String title = 'Fertilizar lote 2',
  String? body,
}) =>
    Alert(
      id: id,
      type: type,
      severity: AlertSeverity.info,
      title: title,
      status: status,
      createdAt: _now,
      body: body,
      scheduledFor: scheduledFor,
    );

void main() {
  group('planReminderNotifications', () {
    test('keeps only pending reminders scheduled in the future', () {
      // Arrange
      final future = _now.add(const Duration(hours: 3));
      final alerts = [
        _alert('a-future', scheduledFor: future, body: 'Urea 50 kg'),
        _alert('b-past', scheduledFor: _now.subtract(const Duration(hours: 1))),
        _alert('c-dismissed',
            status: AlertStatus.dismissed, scheduledFor: future),
        _alert('d-sent', status: AlertStatus.sent, scheduledFor: future),
        _alert('e-weather', type: AlertType.weather, scheduledFor: future),
        _alert('f-no-date'),
      ];

      // Act
      final planned = planReminderNotifications(alerts, now: _now);

      // Assert
      expect(planned.map((p) => p.alertId), ['a-future']);
      expect(planned.single.title, 'Fertilizar lote 2');
      expect(planned.single.body, 'Urea 50 kg');
      expect(planned.single.at, future);
      expect(planned.single.id, notificationIdFor('a-future'));
    });

    test('returns an empty plan for an empty alert list (post-logout wipe)',
        () {
      expect(planReminderNotifications(const [], now: _now), isEmpty);
    });
  });

  group('notificationIdFor', () {
    test('is stable, non-negative and fits in a 31-bit Android int', () {
      const id = '7f3c2a9e-1b44-4c1e-9a1d-0f2e8b6c5d41';
      final first = notificationIdFor(id);

      expect(notificationIdFor(id), first);
      expect(first, greaterThanOrEqualTo(0));
      expect(first, lessThanOrEqualTo(0x7fffffff));
    });

    test('differs for different alert ids', () {
      expect(
        notificationIdFor('7f3c2a9e-1b44-4c1e-9a1d-0f2e8b6c5d41'),
        isNot(notificationIdFor('7f3c2a9e-1b44-4c1e-9a1d-0f2e8b6c5d42')),
      );
    });
  });

  group('ReminderNotificationSync', () {
    late FakeGateway gateway;
    late ReminderNotificationSync sync;

    setUp(() {
      gateway = FakeGateway();
      sync = ReminderNotificationSync(gateway, clock: () => _now);
    });

    test('cancels stale notifications then schedules every planned reminder',
        () async {
      // Arrange
      final alerts = [
        _alert('a', scheduledFor: _now.add(const Duration(hours: 1))),
        _alert('b', scheduledFor: _now.add(const Duration(days: 1))),
      ];

      // Act
      await sync.apply(alerts);

      // Assert
      expect(gateway.calls, ['cancelAll', 'schedule:a', 'schedule:b']);
    });

    test('skips the OS round-trip when the plan has not changed', () async {
      final alerts = [
        _alert('a', scheduledFor: _now.add(const Duration(hours: 1))),
      ];
      await sync.apply(alerts);
      gateway.calls.clear();

      await sync.apply(alerts);

      expect(gateway.calls, isEmpty);
    });

    test('dismissing a reminder cancels its notification', () async {
      final at = _now.add(const Duration(hours: 1));
      await sync.apply([_alert('a', scheduledFor: at)]);

      await sync.apply([
        _alert('a', scheduledFor: at, status: AlertStatus.dismissed),
      ]);

      expect(gateway.scheduled, isEmpty);
      expect(gateway.calls.last, 'cancelAll');
    });

    test('an emptied alert list (logout wipe) cancels everything', () async {
      await sync.apply([
        _alert('a', scheduledFor: _now.add(const Duration(hours: 1))),
      ]);

      await sync.apply(const []);

      expect(gateway.scheduled, isEmpty);
      expect(gateway.calls.last, 'cancelAll');
    });

    test('editing the time reschedules even with the same alert id', () async {
      await sync.apply([
        _alert('a', scheduledFor: _now.add(const Duration(hours: 1))),
      ]);

      final moved = _now.add(const Duration(hours: 5));
      await sync.apply([_alert('a', scheduledFor: moved)]);

      expect(gateway.scheduled.single.at, moved);
    });

    test('overlapping applies are serialized; the last list wins', () async {
      final first = sync.apply([
        _alert('a', scheduledFor: _now.add(const Duration(hours: 1))),
      ]);
      final second = sync.apply([
        _alert('b', scheduledFor: _now.add(const Duration(hours: 2))),
      ]);

      await Future.wait([first, second]);

      expect(gateway.scheduled.map((n) => n.alertId), ['b']);
    });

    test('a plugin failure is swallowed and retried on the next apply',
        () async {
      final alerts = [
        _alert('a', scheduledFor: _now.add(const Duration(hours: 1))),
      ];
      gateway.throwOnSchedule = true;

      await expectLater(sync.apply(alerts), completes);

      gateway.throwOnSchedule = false;
      await sync.apply(alerts);
      expect(gateway.scheduled.map((n) => n.alertId), ['a']);
    });

    test('requestPermission delegates to the gateway', () async {
      gateway.permissionResult = false;

      final granted = await sync.requestPermission();

      expect(granted, isFalse);
      expect(gateway.calls, ['requestPermission']);
    });
  });

  group('reminderNotificationsBindingProvider', () {
    test('reconciles every alerts-stream emission with the OS scheduler',
        () async {
      // Arrange
      final gateway = FakeGateway();
      final repo = MockAlertRepository();
      final alerts = StreamController<List<Alert>>();
      addTearDown(alerts.close);
      when(repo.watchAll).thenAnswer((_) => alerts.stream);
      final container = ProviderContainer(overrides: [
        alertRepositoryProvider.overrideWithValue(repo),
        notificationGatewayProvider.overrideWithValue(gateway),
      ]);
      addTearDown(container.dispose);

      // Act — subscribe, then emit a far-future reminder and a wipe.
      container.read(reminderNotificationsBindingProvider);
      alerts.add([
        _alert('a', scheduledFor: DateTime.now().add(const Duration(days: 30))),
      ]);
      await pumpEventQueue();
      final afterCreate = gateway.scheduled.map((n) => n.alertId).toList();
      alerts.add(const []);
      await pumpEventQueue();

      // Assert
      expect(afterCreate, ['a']);
      expect(gateway.scheduled, isEmpty);
    });
  });
}
