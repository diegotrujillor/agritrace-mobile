import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/repositories/activity_repository.dart';
import 'package:agritrace_mobile/repositories/alert_repository.dart';
import 'package:agritrace_mobile/repositories/farm_repository.dart';
import 'package:agritrace_mobile/repositories/plot_repository.dart';
import 'package:agritrace_mobile/services/sync_orchestrator.dart';
import 'package:agritrace_mobile/services/sync_service.dart';

class _MockSyncService extends Mock implements SyncService {}

class _MockFarmRepo extends Mock implements FarmRepository {}

class _MockPlotRepo extends Mock implements PlotRepository {}

class _MockActivityRepo extends Mock implements ActivityRepository {}

class _MockAlertRepo extends Mock implements AlertRepository {}

SyncResult _pullResult(List<Map<String, dynamic>> changes) => SyncResult(
      synced: 0,
      conflicts: 0,
      pulledChanges: changes,
      timestamp: DateTime.utc(2026, 5, 25),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<SyncChange>[]);
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockSyncService syncService;
  late _MockFarmRepo farmRepo;
  late _MockPlotRepo plotRepo;
  late _MockActivityRepo activityRepo;
  late _MockAlertRepo alertRepo;
  late SyncOrchestrator orchestrator;

  setUp(() {
    syncService = _MockSyncService();
    farmRepo = _MockFarmRepo();
    plotRepo = _MockPlotRepo();
    activityRepo = _MockActivityRepo();
    alertRepo = _MockAlertRepo();
    orchestrator = SyncOrchestrator(
      syncService: syncService,
      farmRepo: farmRepo,
      plotRepo: plotRepo,
      activityRepo: activityRepo,
      alertRepo: alertRepo,
    );

    // Default: every repo returns empty pending lists. Tests that need
    // pending rows override per-case.
    when(() => farmRepo.upsertFromServer(any())).thenAnswer((_) async {});
    when(() => plotRepo.upsertFromServer(any())).thenAnswer((_) async {});
    when(() => activityRepo.upsertFromServer(any())).thenAnswer((_) async {});
    when(() => alertRepo.upsertFromServer(any())).thenAnswer((_) async {});
  });

  // v1.9.8 — P0 fix. `pullAllFromServer()` is invoked by `AuthService`
  // after every successful login/register so the dashboard rebuild sees a
  // populated local Drift DB.
  group('pullAllFromServer (P0)', () {
    test('calls syncNow() with no `since` so the backend returns all rows',
        () async {
      // Backend semantics: `GET /v1/sync/changes` with no `since` query
      // param → return every row for the producer (verified against
      // agritrace-backend/src/services/sync.service.ts).
      when(() => syncService.syncNow(
            changes: any(named: 'changes'),
            since: any(named: 'since'),
          )).thenAnswer((_) async => _pullResult(const []));

      await orchestrator.pullAllFromServer();

      final call = verify(() => syncService.syncNow(
            changes: captureAny(named: 'changes'),
            since: captureAny(named: 'since'),
          )).captured;
      expect(call[0], isEmpty, reason: 'pull-only — no pushed changes');
      expect(call[1], isNull, reason: 'no cursor → full pull');
    });

    test('upserts every pulled farm/plot/activity/alert via the repositories',
        () async {
      when(() => syncService.syncNow(
            changes: any(named: 'changes'),
            since: any(named: 'since'),
          )).thenAnswer((_) async => _pullResult([
            {'entity': 'farm', 'id': 'f1', 'data': {}},
            {'entity': 'farm', 'id': 'f2', 'data': {}},
            {'entity': 'plot', 'id': 'p1', 'data': {}},
            {'entity': 'activity', 'id': 'a1', 'data': {}},
            {'entity': 'alert', 'id': 'al1', 'data': {}},
          ]));

      await orchestrator.pullAllFromServer();

      verify(() => farmRepo.upsertFromServer(any())).called(2);
      verify(() => plotRepo.upsertFromServer(any())).called(1);
      verify(() => activityRepo.upsertFromServer(any())).called(1);
      verify(() => alertRepo.upsertFromServer(any())).called(1);
    });

    test('throws on transport error so AuthService can log it', () async {
      // The puller must NOT swallow errors here — AuthService is the
      // single chokepoint where the offline-tolerance decision lives.
      when(() => syncService.syncNow(
            changes: any(named: 'changes'),
            since: any(named: 'since'),
          )).thenThrow(Exception('network down'));

      expect(orchestrator.pullAllFromServer(), throwsA(isA<Exception>()));
    });

    test('does NOT push pending local changes (pull-only contract)', () async {
      // Even if the local DB held pending rows, `pullAllFromServer` must
      // not flush them — that is the job of the regular `run()` cycle.
      // Otherwise a freshly logged-in user would push the previous
      // session's leftover pending rows before this session's user even
      // appears on the dashboard.
      when(() => syncService.syncNow(
            changes: any(named: 'changes'),
            since: any(named: 'since'),
          )).thenAnswer((_) async => _pullResult(const []));

      await orchestrator.pullAllFromServer();

      verifyNever(() => farmRepo.getPending());
      verifyNever(() => plotRepo.getPending());
      verifyNever(() => activityRepo.getPending());
      verifyNever(() => alertRepo.getPending());
    });
  });
}
