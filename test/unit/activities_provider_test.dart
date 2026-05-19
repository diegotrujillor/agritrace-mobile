import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/providers/activities_provider.dart';
import 'package:agritrace_mobile/services/activity_service.dart';

class MockActivityService extends Mock implements ActivityService {}

const _plotId = 'plot-1';

Activity _activity({String id = 'act-1'}) => Activity(
      id: id,
      plotId: _plotId,
      type: ActivityType.sowing,
      occurredAt: DateTime.utc(2026, 3, 1),
      createdAt: DateTime.utc(2026, 3, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(ActivityType.other);
    registerFallbackValue(DateTime.utc(2026));
  });

  late MockActivityService mockService;

  setUp(() {
    mockService = MockActivityService();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [activityServiceProvider.overrideWithValue(mockService)],
      );

  test('build() loads activities for the given plot', () async {
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_activity()]);
    final container = makeContainer();
    addTearDown(container.dispose);

    final acts = await container.read(activitiesProvider(_plotId).future);

    expect(acts.single.id, 'act-1');
    verify(() => mockService.listByPlot(_plotId)).called(1);
  });

  test('createActivity() calls the service then refreshes', () async {
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => <Activity>[]);
    when(() => mockService.create(
          plotId: any(named: 'plotId'),
          type: any(named: 'type'),
          occurredAt: any(named: 'occurredAt'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        )).thenAnswer((_) async => _activity());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_activity()]);
    final occurred = DateTime.utc(2026, 3, 1);
    await container.read(activitiesProvider(_plotId).notifier).createActivity(
          type: ActivityType.sowing,
          occurredAt: occurred,
        );

    expect(container.read(activitiesProvider(_plotId)).value, hasLength(1));
    verify(() => mockService.create(
          plotId: _plotId,
          type: ActivityType.sowing,
          occurredAt: occurred,
          description: null,
          photoUrl: null,
        )).called(1);
  });

  test('updateActivity() calls the service then refreshes', () async {
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_activity()]);
    when(() => mockService.update(
          id: any(named: 'id'),
          plotId: any(named: 'plotId'),
          type: any(named: 'type'),
          occurredAt: any(named: 'occurredAt'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        )).thenAnswer((_) async => _activity());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    final occurred = DateTime.utc(2026, 3, 5);
    await container.read(activitiesProvider(_plotId).notifier).updateActivity(
          id: 'act-1',
          type: ActivityType.harvest,
          occurredAt: occurred,
        );

    verify(() => mockService.update(
          id: 'act-1',
          plotId: _plotId,
          type: ActivityType.harvest,
          occurredAt: occurred,
          description: null,
          photoUrl: null,
        )).called(1);
  });

  test('deleteActivity() calls the service then refreshes', () async {
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_activity()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => <Activity>[]);
    await container
        .read(activitiesProvider(_plotId).notifier)
        .deleteActivity('act-1');

    expect(container.read(activitiesProvider(_plotId)).value, isEmpty);
    verify(() => mockService.delete('act-1')).called(1);
  });

  test('build() surfaces an AsyncError when the service throws', () async {
    when(() => mockService.listByPlot(_plotId))
        .thenThrow(Exception('network down'));
    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(activitiesProvider(_plotId).future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(activitiesProvider(_plotId)).hasError, isTrue);
  });

  test('deleteActivity() error state when refresh fails', () async {
    when(() => mockService.listByPlot(_plotId))
        .thenAnswer((_) async => [_activity()]);
    when(() => mockService.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    when(() => mockService.listByPlot(_plotId))
        .thenThrow(Exception('refresh failed'));
    await container
        .read(activitiesProvider(_plotId).notifier)
        .deleteActivity('act-1');

    expect(container.read(activitiesProvider(_plotId)).hasError, isTrue);
  });

  test('activityProvider.family looks up a single activity by id', () async {
    when(() => mockService.get('act-9'))
        .thenAnswer((_) async => _activity(id: 'act-9'));
    final container = makeContainer();
    addTearDown(container.dispose);

    final act = await container.read(activityProvider('act-9').future);

    expect(act.id, 'act-9');
  });
}
