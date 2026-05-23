import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/services/sync_service.dart';

import '_helpers.dart';

void main() {
  late MockApiService api;
  late MockDio dio;
  late SyncService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = SyncService(api);
  });

  /// Wraps `body` in the `{success, data}` envelope the backend returns from
  /// `POST /v1/sync` (see backend `src/api/sync/sync.controller.ts:16`).
  /// Callers pass the inner result; the helper handles the wrapping —
  /// matches the `stubPull` idiom in this file. Tests that intentionally
  /// stub a malformed envelope should call `dio.post(...)` directly
  /// instead of going through this helper.
  void stubPush(Map<String, dynamic> body) {
    when(() => dio.post('/sync', data: any(named: 'data')))
        .thenAnswer((_) async => okResponse(envelope(body)));
  }

  void stubPull(Map<String, dynamic> body) {
    when(() => dio.get('/sync/changes',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => okResponse(body));
  }

  test('syncNow() pushes changes then pulls and aggregates result', () async {
    stubPush({
      'synced': 2,
      'conflicts': 1,
      'timestamp': '2026-05-01T00:00:00.000Z',
    });
    stubPull(envelope({
      'changes': [
        {'entity': 'farm', 'id': 'f1', 'action': 'update', 'data': {}},
      ],
      'timestamp': '2026-05-01T00:05:00.000Z',
    }));

    final result = await service.syncNow(
      changes: const [
        SyncChange(entity: 'farm', id: 'f1', action: 'create', data: {}),
      ],
      since: DateTime.utc(2026, 4, 30),
    );

    expect(result.synced, 2);
    expect(result.conflicts, 1);
    expect(result.pulledChanges, hasLength(1));
    expect(result.timestamp, DateTime.utc(2026, 5, 1, 0, 5));
  });

  test('syncNow() serialises changes and sends since cursor', () async {
    stubPush({'synced': 1, 'conflicts': 0});
    stubPull(envelope({'changes': [], 'timestamp': '2026-05-01T00:00:00.000Z'}));

    await service.syncNow(
      changes: const [
        SyncChange(
          entity: 'plot',
          id: 'p1',
          action: 'update',
          data: {'name': 'Lote'},
        ),
      ],
      since: DateTime.utc(2026, 4, 29, 12),
    );

    final pushData = verify(
      () => dio.post('/sync', data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(pushData['changes'], [
      {'entity': 'plot', 'id': 'p1', 'action': 'update', 'data': {'name': 'Lote'}},
    ]);

    final pullQuery = verify(
      () => dio.get('/sync/changes',
          queryParameters: captureAny(named: 'queryParameters')),
    ).captured.single as Map;
    expect(pullQuery['since'], DateTime.utc(2026, 4, 29, 12).toIso8601String());
  });

  test('syncNow() omits since on first run (null cursor)', () async {
    stubPush({'synced': 0, 'conflicts': 0});
    stubPull(envelope({'changes': [], 'timestamp': '2026-05-01T00:00:00.000Z'}));

    await service.syncNow();

    final pullQuery = verify(
      () => dio.get('/sync/changes',
          queryParameters: captureAny(named: 'queryParameters')),
    ).captured.single as Map;
    expect(pullQuery.containsKey('since'), isFalse);
  });

  test('throws FormatException when push envelope is invalid', () async {
    // Bypass stubPush to inject a deliberately malformed envelope.
    when(() => dio.post('/sync', data: any(named: 'data')))
        .thenAnswer((_) async => okResponse({'success': false}));
    stubPull(envelope({'changes': [], 'timestamp': '2026-05-01T00:00:00.000Z'}));

    expect(service.syncNow(), throwsA(isA<FormatException>()));
  });

  test('throws FormatException when pull envelope lacks data', () async {
    stubPush({'synced': 0, 'conflicts': 0});
    when(() => dio.get('/sync/changes',
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => okResponse({'success': true}));

    expect(service.syncNow(), throwsA(isA<FormatException>()));
  });

  test('coerces string counters and falls back on bad timestamp', () async {
    stubPush({'synced': '5', 'conflicts': '0'});
    stubPull(envelope({'changes': null, 'timestamp': 12345}));

    final result = await service.syncNow();

    expect(result.synced, 5);
    expect(result.conflicts, 0);
    expect(result.pulledChanges, isEmpty);
    expect(result.timestamp.isUtc, isTrue);
  });

  test('propagates DioException from the push leg', () async {
    when(() => dio.post('/sync', data: any(named: 'data'))).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/sync')),
    );

    expect(service.syncNow(), throwsA(isA<DioException>()));
  });
}
