import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/providers/sync_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/sync_service.dart';
import 'package:agritrace_mobile/services/sync_orchestrator.dart';

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

SyncResult _result({DateTime? ts, int synced = 1, int conflicts = 0}) =>
    SyncResult(
      synced: synced,
      conflicts: conflicts,
      pulledChanges: const [],
      timestamp: ts ?? DateTime.utc(2026, 5, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<SyncChange>[]);
  });

  late MockSyncOrchestrator mockOrchestrator;

  setUp(() {
    mockOrchestrator = MockSyncOrchestrator();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );

  test('initial state is idle (null data, no error)', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    final result = await container.read(syncProvider.future);

    expect(result, isNull);
    expect(container.read(syncProvider).hasError, isFalse);
  });

  test('trigger() transitions idle -> success with the sync result', () async {
    when(() => mockOrchestrator.run(since: any(named: 'since')))
        .thenAnswer((_) async => _result(synced: 3));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(syncProvider.future);

    await container.read(syncProvider.notifier).trigger();

    final state = container.read(syncProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.synced, 3);
  });

  test('trigger() passes the previous timestamp as the next since cursor',
      () async {
    final firstTs = DateTime.utc(2026, 5, 1, 10);
    when(() => mockOrchestrator.run(since: any(named: 'since')))
        .thenAnswer((_) async => _result(ts: firstTs));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(syncProvider.future);

    await container.read(syncProvider.notifier).trigger();
    await container.read(syncProvider.notifier).trigger();

    final calls = verify(
      () => mockOrchestrator.run(since: captureAny(named: 'since')),
    ).captured;
    expect(calls.first, isNull); // first run: no cursor
    expect(calls.last, firstTs); // second run: cursor from first result
  });

  test('trigger() transitions idle -> error when the orchestrator throws',
      () async {
    when(() => mockOrchestrator.run(since: any(named: 'since')))
        .thenThrow(Exception('sync failed'));

    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(syncProvider.future);

    await container.read(syncProvider.notifier).trigger();

    expect(container.read(syncProvider).hasError, isTrue);
  });
}
