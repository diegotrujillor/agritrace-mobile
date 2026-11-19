import 'package:agritrace_mobile/providers/reminder_notifications_provider.dart';
import 'package:agritrace_mobile/services/reminder_notifications.dart';
import 'package:agritrace_mobile/widgets/domain/notification_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements NotificationGateway {
  _FakeGateway({this.enabled = true});

  bool enabled;
  int testShown = 0;

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<void> showTest() async => testShown++;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(PlannedNotification notification) async {}

  @override
  Future<bool> requestPermission() async => enabled;
}

Future<int> _pump(
  WidgetTester tester, {
  required _FakeGateway gateway,
  String? syncError,
}) async {
  var settingsOpened = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationGatewayProvider.overrideWithValue(gateway),
        reminderSyncErrorProvider.overrideWith((_) => syncError),
        appSettingsOpenerProvider.overrideWithValue(() async {
          settingsOpened++;
          return true;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [TestNotificationButton()]),
          body: const NotificationStatusBanner(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settingsOpened;
}

void main() {
  group('NotificationStatusBanner', () {
    testWidgets('warns and offers Activar when notifications are disabled',
        (tester) async {
      // Arrange
      var opened = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationGatewayProvider
                .overrideWithValue(_FakeGateway(enabled: false)),
            appSettingsOpenerProvider.overrideWithValue(() async {
              opened++;
              return true;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: NotificationStatusBanner()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      expect(find.text('Notificaciones desactivadas'), findsOneWidget);
      await tester.tap(find.text('Activar'));
      await tester.pump();

      // Assert
      expect(opened, 1);
    });

    testWidgets('renders nothing when notifications work', (tester) async {
      await _pump(tester, gateway: _FakeGateway());

      expect(find.text('Notificaciones desactivadas'), findsNothing);
      expect(find.textContaining('No se pudieron programar'), findsNothing);
    });

    testWidgets('shows the scheduling error when the last sync failed',
        (tester) async {
      await _pump(
        tester,
        gateway: _FakeGateway(),
        syncError: 'PlatformException(boom)',
      );

      expect(find.textContaining('No se pudieron programar'), findsOneWidget);
    });
  });

  group('TestNotificationButton', () {
    testWidgets('fires a test notification when enabled', (tester) async {
      // Arrange
      final gateway = _FakeGateway();
      await _pump(tester, gateway: gateway);

      // Act
      await tester.tap(find.byTooltip('Probar notificación'));
      await tester.pumpAndSettle();

      // Assert
      expect(gateway.testShown, 1);
      expect(find.textContaining('Notificación de prueba enviada'),
          findsOneWidget);
    });

    testWidgets('asks to enable notifications instead when disabled',
        (tester) async {
      // Arrange
      final gateway = _FakeGateway(enabled: false);
      await _pump(tester, gateway: gateway);

      // Act
      await tester.tap(find.byTooltip('Probar notificación'));
      await tester.pumpAndSettle();

      // Assert
      expect(gateway.testShown, 0);
      expect(find.textContaining('Activa las notificaciones'), findsOneWidget);
    });
  });
}
