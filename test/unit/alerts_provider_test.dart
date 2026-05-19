import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/alert.dart';
import 'package:agritrace_mobile/providers/alerts_provider.dart';
import 'package:agritrace_mobile/services/alert_service.dart';

class MockAlertService extends Mock implements AlertService {}

Alert _alert({String id = 'alert-1', AlertStatus status = AlertStatus.pending}) =>
    Alert(
      id: id,
      type: AlertType.reminder,
      severity: AlertSeverity.info,
      title: 'Regar lote',
      status: status,
      createdAt: DateTime.utc(2026, 4, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026));
  });

  late MockAlertService mockService;

  setUp(() {
    mockService = MockAlertService();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [alertServiceProvider.overrideWithValue(mockService)],
      );

  test('build() loads the producer alerts list', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_alert()]);
    final container = makeContainer();
    addTearDown(container.dispose);

    final alerts = await container.read(alertsProvider.future);

    expect(alerts.single.id, 'alert-1');
    verify(() => mockService.list()).called(1);
  });

  test('createReminder() calls the service then refreshes', () async {
    when(() => mockService.list()).thenAnswer((_) async => <Alert>[]);
    when(() => mockService.createReminder(
          title: any(named: 'title'),
          scheduledFor: any(named: 'scheduledFor'),
          body: any(named: 'body'),
          plotId: any(named: 'plotId'),
        )).thenAnswer((_) async => _alert());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockService.list()).thenAnswer((_) async => [_alert()]);
    final when0 = DateTime.utc(2026, 4, 2, 8);
    await container.read(alertsProvider.notifier).createReminder(
          title: 'Regar lote',
          scheduledFor: when0,
        );

    expect(container.read(alertsProvider).value, hasLength(1));
    verify(() => mockService.createReminder(
          title: 'Regar lote',
          scheduledFor: when0,
          body: null,
          plotId: null,
        )).called(1);
  });

  test('dismiss() updates the alert status then refreshes', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_alert()]);
    when(() => mockService.update(any(), status: any(named: 'status')))
        .thenAnswer((_) async => _alert(status: AlertStatus.dismissed));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockService.list())
        .thenAnswer((_) async => [_alert(status: AlertStatus.dismissed)]);
    await container.read(alertsProvider.notifier).dismiss('alert-1');

    expect(container.read(alertsProvider).value!.single.status,
        AlertStatus.dismissed);
    verify(() => mockService.update('alert-1',
        status: AlertStatus.dismissed)).called(1);
  });

  test('deleteAlert() calls the service then refreshes', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_alert()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockService.list()).thenAnswer((_) async => <Alert>[]);
    await container.read(alertsProvider.notifier).deleteAlert('alert-1');

    expect(container.read(alertsProvider).value, isEmpty);
    verify(() => mockService.delete('alert-1')).called(1);
  });

  test('runWeatherCheck() returns provider name and refreshes', () async {
    when(() => mockService.list()).thenAnswer((_) async => <Alert>[]);
    when(() => mockService.checkWeather('plot-1')).thenAnswer(
      (_) async => const WeatherCheckResult(provider: 'stub'),
    );

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockService.list()).thenAnswer((_) async => [_alert()]);
    final provider = await container
        .read(alertsProvider.notifier)
        .runWeatherCheck('plot-1');

    expect(provider, 'stub');
    expect(container.read(alertsProvider).value, hasLength(1));
  });

  test('build() surfaces an AsyncError when the service throws', () async {
    when(() => mockService.list()).thenThrow(Exception('network down'));
    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(alertsProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(alertsProvider).hasError, isTrue);
  });

  test('deleteAlert() error state when refresh fails', () async {
    when(() => mockService.list()).thenAnswer((_) async => [_alert()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockService.list()).thenThrow(Exception('refresh failed'));
    await container.read(alertsProvider.notifier).deleteAlert('alert-1');

    expect(container.read(alertsProvider).hasError, isTrue);
  });
}
