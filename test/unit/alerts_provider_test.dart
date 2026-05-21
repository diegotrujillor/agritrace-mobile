import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/alert.dart';
import 'package:agritrace_mobile/providers/alerts_provider.dart';
import 'package:agritrace_mobile/repositories/alert_repository.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/alert_service.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

class MockAlertService extends Mock implements AlertService {}

Alert _alert({
  String id = 'alert-1',
  AlertStatus status = AlertStatus.pending,
}) =>
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
    registerFallbackValue(_alert());
    registerFallbackValue(AlertStatus.pending);
  });

  late MockAlertRepository mockRepo;
  late MockAlertService mockService;

  setUp(() {
    mockRepo = MockAlertRepository();
    mockService = MockAlertService();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          alertRepositoryProvider.overrideWithValue(mockRepo),
          alertServiceProvider.overrideWithValue(mockService),
        ],
      );

  void stubRepoDefaults(List<Alert> alerts) {
    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.value(alerts));
  }

  test('build() loads the producer alerts list', () async {
    stubRepoDefaults([_alert()]);

    final container = makeContainer();
    addTearDown(container.dispose);

    final alerts = await container.read(alertsProvider.future);

    expect(alerts.single.id, 'alert-1');
    verify(() => mockRepo.watchAll()).called(greaterThanOrEqualTo(1));
  });

  test('createReminder() calls repo then refreshes', () async {
    stubRepoDefaults([]);
    when(() => mockRepo.createReminder(
          title: any(named: 'title'),
          scheduledFor: any(named: 'scheduledFor'),
          body: any(named: 'body'),
          plotId: any(named: 'plotId'),
        )).thenAnswer((_) async => _alert());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.value([_alert()]));
    final when0 = DateTime.utc(2026, 4, 2, 8);
    await container.read(alertsProvider.notifier).createReminder(
          title: 'Regar lote',
          scheduledFor: when0,
        );

    expect(container.read(alertsProvider).value, hasLength(1));
    verify(() => mockRepo.createReminder(
          title: 'Regar lote',
          scheduledFor: when0,
          body: null,
          plotId: null,
        )).called(1);
  });

  test('dismiss() updates the alert status then refreshes', () async {
    stubRepoDefaults([_alert()]);
    when(() => mockRepo.updateStatus(any(), any()))
        .thenAnswer((_) async => _alert(status: AlertStatus.dismissed));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockRepo.watchAll()).thenAnswer(
      (_) => Stream.value([_alert(status: AlertStatus.dismissed)]),
    );
    await container.read(alertsProvider.notifier).dismiss('alert-1');

    expect(container.read(alertsProvider).value!.single.status,
        AlertStatus.dismissed);
    verify(() => mockRepo.updateStatus(any(), AlertStatus.dismissed))
        .called(1);
  });

  test('deleteAlert() calls repo delete then refreshes', () async {
    stubRepoDefaults([_alert()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.value(<Alert>[]));
    await container.read(alertsProvider.notifier).deleteAlert('alert-1');

    expect(container.read(alertsProvider).value, isEmpty);
    verify(() => mockRepo.delete('alert-1')).called(1);
  });

  test('runWeatherCheck() returns provider name and refreshes', () async {
    stubRepoDefaults([]);
    when(() => mockService.checkWeather('plot-1')).thenAnswer(
      (_) async => WeatherCheckResult(
        provider: 'stub',
        alert: _alert(id: 'w-1'),
      ),
    );
    when(() => mockRepo.upsertFromServer(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.value([_alert()]));
    final provider = await container
        .read(alertsProvider.notifier)
        .runWeatherCheck('plot-1');

    expect(provider, 'stub');
    expect(container.read(alertsProvider).value, hasLength(1));
  });

  test('build() surfaces an AsyncError when the repo stream errors', () async {
    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.error(Exception('db error')));

    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(alertsProvider.future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(alertsProvider).hasError, isTrue);
  });

  test('deleteAlert() error state when repo throws', () async {
    stubRepoDefaults([_alert()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(alertsProvider.future);

    when(() => mockRepo.watchAll())
        .thenAnswer((_) => Stream.error(Exception('refresh failed')));
    await container.read(alertsProvider.notifier).deleteAlert('alert-1');

    expect(container.read(alertsProvider).hasError, isTrue);
  });
}
