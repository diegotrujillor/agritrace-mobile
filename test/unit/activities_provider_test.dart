import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/providers/activities_provider.dart';
import 'package:agritrace_mobile/repositories/activity_repository.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/activity_service.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

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
    registerFallbackValue(_activity());
  });

  late MockActivityRepository mockRepo;
  late MockActivityService mockService;

  setUp(() {
    mockRepo = MockActivityRepository();
    mockService = MockActivityService();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          activityRepositoryProvider.overrideWithValue(mockRepo),
          activityServiceProvider.overrideWithValue(mockService),
        ],
      );

  void stubRepoDefaults(List<Activity> acts) {
    when(() => mockRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value(acts));
    when(() => mockRepo.listByPlot(any())).thenAnswer((_) async => acts);
  }

  test('build() loads activities for the given plot', () async {
    stubRepoDefaults([_activity()]);

    final container = makeContainer();
    addTearDown(container.dispose);

    final acts = await container.read(activitiesProvider(_plotId).future);

    expect(acts.single.id, 'act-1');
    verify(() => mockRepo.listByPlot(_plotId)).called(greaterThanOrEqualTo(1));
  });

  test('createActivity() calls repo then refreshes', () async {
    stubRepoDefaults([]);
    when(() => mockRepo.create(
          plotId: any(named: 'plotId'),
          type: any(named: 'type'),
          occurredAt: any(named: 'occurredAt'),
          description: any(named: 'description'),
          photoUrl: any(named: 'photoUrl'),
        )).thenAnswer((_) async => _activity());

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    when(() => mockRepo.listByPlot(_plotId))
        .thenAnswer((_) async => [_activity()]);
    final occurred = DateTime.utc(2026, 3, 1);
    await container
        .read(activitiesProvider(_plotId).notifier)
        .createActivity(
          type: ActivityType.sowing,
          occurredAt: occurred,
        );

    expect(container.read(activitiesProvider(_plotId)).value, hasLength(1));
    verify(() => mockRepo.create(
          plotId: _plotId,
          type: ActivityType.sowing,
          occurredAt: occurred,
          description: null,
          photoUrl: null,
        )).called(1);
  });

  test('updateActivity() calls repo update then refreshes', () async {
    stubRepoDefaults([_activity()]);
    when(() => mockRepo.update(
          any(),
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

    verify(() => mockRepo.update(
          any(),
          type: ActivityType.harvest,
          occurredAt: occurred,
          description: null,
          photoUrl: null,
        )).called(1);
  });

  test('deleteActivity() calls repo delete then refreshes', () async {
    stubRepoDefaults([_activity()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    when(() => mockRepo.listByPlot(_plotId))
        .thenAnswer((_) async => <Activity>[]);
    await container
        .read(activitiesProvider(_plotId).notifier)
        .deleteActivity('act-1');

    expect(container.read(activitiesProvider(_plotId)).value, isEmpty);
    verify(() => mockRepo.delete('act-1')).called(1);
  });

  test('build() surfaces an AsyncError when the repo throws', () async {
    when(() => mockRepo.watchByPlot(any()))
        .thenAnswer((_) => Stream.value([]));
    when(() => mockRepo.listByPlot(_plotId))
        .thenThrow(Exception('db error'));

    final container = makeContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(activitiesProvider(_plotId).future),
      throwsA(isA<Exception>()),
    );
    expect(container.read(activitiesProvider(_plotId)).hasError, isTrue);
  });

  test('deleteActivity() error state when repo throws', () async {
    stubRepoDefaults([_activity()]);
    when(() => mockRepo.delete(any())).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(activitiesProvider(_plotId).future);

    when(() => mockRepo.listByPlot(_plotId))
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
