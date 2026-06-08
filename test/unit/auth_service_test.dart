import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';

import '_helpers.dart';

class _MockStorageService extends Mock implements StorageService {}

/// v1.9.11 — mocktail needs a fallback value registered before `any()`
/// can be used on a non-primitive `User` argument. The snapshot is written
/// on every login/register/refresh so the stub for `saveUserSnapshot`
/// uses `any()` to match arbitrary `User` instances.
const _fallbackUser = User(
  id: '__fallback__',
  email: 'fallback@example.com',
  fullName: 'Fallback',
  phone: '',
  role: UserRole.producer,
);

Map<String, dynamic> _authEnvelope({
  String accessToken = 'acc',
  String refreshToken = 'ref',
}) =>
    {
      'success': true,
      'data': {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'user': {
          'id': 'u-1',
          'email': 'a@b.com',
          'fullName': 'Ana',
          'phone': '+57 300',
          'role': 'producer',
        },
      },
    };

void main() {
  setUpAll(() {
    registerFallbackValue(_fallbackUser);
  });

  late MockApiService api;
  late MockDio dio;
  late _MockStorageService storage;
  late AuthService service;

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    storage = _MockStorageService();
    when(() => api.client).thenReturn(dio);
    when(() => storage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => storage.deleteTokens()).thenAnswer((_) async {});
    // v1.9.3 — P0 fix. login/register/refresh now persist `last_user_id`
    // and check it for cross-account wipe; logout fans out to deleteAll.
    // Default stubs cover the legacy tests; cross-user tests override
    // `getLastUserId` per case.
    when(() => storage.saveLastUserId(any())).thenAnswer((_) async {});
    when(() => storage.getLastUserId()).thenAnswer((_) async => null);
    when(() => storage.deleteAll()).thenAnswer((_) async {});
    // v1.9.11 — login/register/refresh now persist a user snapshot
    // alongside the tokens. Stub the new method so the legacy auth-service
    // tests don't fail when mocktail sees an unstubbed invocation.
    when(() => storage.saveUserSnapshot(any())).thenAnswer((_) async {});
    service = AuthService(api, storage);
  });

  group('login', () {
    test('POSTs /auth/login with credentials and persists tokens', () async {
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope(
                accessToken: 'A1',
                refreshToken: 'R1',
              )));

      final auth = await service.login(
        email: 'a@b.com',
        password: 'pwd-12345',
      );

      expect(auth.accessToken, 'A1');
      expect(auth.refreshToken, 'R1');
      expect(auth.user.email, 'a@b.com');

      final captured = verify(
        () => dio.post('/auth/login', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['email'], 'a@b.com');
      expect(captured['password'], 'pwd-12345');

      verify(() => storage.saveTokens(accessToken: 'A1', refreshToken: 'R1'))
          .called(1);
    });

    test('propagates DioException', () async {
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/auth/login')));

      expect(
        service.login(email: 'a@b.com', password: 'x'),
        throwsA(isA<DioException>()),
      );
    });

    test('throws FormatException on malformed envelope', () async {
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse({'success': false}));

      expect(
        service.login(email: 'a@b.com', password: 'x'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('register', () {
    test('POSTs /auth/register and never sends role', () async {
      when(() => dio.post('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      await service.register(
        fullName: 'Ana B',
        phone: '+57 300',
        email: 'a@b.com',
        password: 'pwd-12345',
        privacyConsent: true,
      );

      final captured = verify(
        () => dio.post('/auth/register', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['fullName'], 'Ana B');
      expect(captured['phone'], '+57 300');
      expect(captured['email'], 'a@b.com');
      expect(captured['password'], 'pwd-12345');
      expect(captured['privacyConsent'], isTrue);
      expect(captured['privacyConsentVersion'], '1.0');
      expect(captured.containsKey('role'), isFalse,
          reason: 'role must be assigned by the server');
    });

    test('uses the explicit privacyConsentVersion override when provided',
        () async {
      when(() => dio.post('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      await service.register(
        fullName: 'Ana B',
        phone: '+57 300',
        email: 'a@b.com',
        password: 'pwd-12345',
        privacyConsent: true,
        privacyConsentVersion: '2.0',
      );

      final captured = verify(
        () => dio.post('/auth/register', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['privacyConsentVersion'], '2.0');
    });

    test('persists tokens returned by the server', () async {
      when(() => dio.post('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope(
                accessToken: 'NEW-A',
                refreshToken: 'NEW-R',
              )));

      await service.register(
        fullName: 'Ana',
        phone: '300',
        email: 'a@b.com',
        password: 'pwd-12345',
        privacyConsent: true,
      );

      verify(() => storage.saveTokens(
            accessToken: 'NEW-A',
            refreshToken: 'NEW-R',
          )).called(1);
    });
  });

  group('logout', () {
    test('skips network call when no refresh token is stored', () async {
      when(() => storage.getRefreshToken()).thenAnswer((_) async => null);

      await service.logout();

      verifyNever(() => dio.post(any(), data: any(named: 'data')));
      // v1.9.3 — logout now fans out to `deleteAll` (tokens AND
      // `last_user_id`) so secure storage retains nothing.
      verify(() => storage.deleteAll()).called(1);
    });

    test('skips network call when refresh token is empty', () async {
      when(() => storage.getRefreshToken()).thenAnswer((_) async => '');

      await service.logout();

      verifyNever(() => dio.post(any(), data: any(named: 'data')));
      verify(() => storage.deleteAll()).called(1);
    });

    test('POSTs /auth/logout with refresh token when present', () async {
      when(() => storage.getRefreshToken()).thenAnswer((_) async => 'R-token');
      when(() => dio.post('/auth/logout', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse({'success': true}));

      await service.logout();

      final captured = verify(
        () => dio.post('/auth/logout', data: captureAny(named: 'data')),
      ).captured.single as Map<String, dynamic>;
      expect(captured['refreshToken'], 'R-token');
      verify(() => storage.deleteAll()).called(1);
    });

    test('still deletes local tokens when server logout fails', () async {
      when(() => storage.getRefreshToken()).thenAnswer((_) async => 'R-token');
      when(() => dio.post('/auth/logout', data: any(named: 'data')))
          .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/auth/logout')));

      await service.logout();

      verify(() => storage.deleteAll()).called(1);
    });
  });

  // v1.9.3 — P0 fix. Cross-account data-leak protection on the local
  // Drift DB. AuthService accepts a `DataWiper` callback that the
  // provider layer binds to `AppDatabase.wipeAllUserData`. Tests use a
  // counter to assert the wipe ran (or didn't) without dragging Drift
  // into the unit-test build.
  group('cross-user data wipe (P0)', () {
    test('logout always invokes the wiper, even on server failure',
        () async {
      int wipeCalls = 0;
      Future<void> wiper() async => wipeCalls++;
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      when(() => storage.getRefreshToken()).thenAnswer((_) async => 'R-X');
      when(() => dio.post('/auth/logout', data: any(named: 'data')))
          .thenThrow(DioException(
              requestOptions: RequestOptions(path: '/auth/logout')));

      await svc.logout();

      // Wiper must run AND secure storage must be cleared, regardless
      // of whether the server `/auth/logout` round-trip succeeded.
      expect(wipeCalls, 1,
          reason: 'wipe runs in finally, even after server error');
      verify(() => storage.deleteAll()).called(1);
    });

    test('login wipes when the new user id differs from the cached one',
        () async {
      int wipeCalls = 0;
      Future<void> wiper() async => wipeCalls++;
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      // Different user id was last on this device — the new login must
      // tear down the previous user's Drift rows before mounting.
      when(() => storage.getLastUserId())
          .thenAnswer((_) async => 'OTHER-USER');
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      await svc.login(email: 'a@b.com', password: 'pwd-12345');

      expect(wipeCalls, 1, reason: 'cross-account login must wipe');
      verify(() => storage.saveLastUserId('u-1')).called(1);
    });

    test('login does NOT wipe when the new user id matches the cached one',
        () async {
      int wipeCalls = 0;
      Future<void> wiper() async => wipeCalls++;
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      // Same account re-logging in (e.g. token refresh recovery) must
      // preserve local data.
      when(() => storage.getLastUserId()).thenAnswer((_) async => 'u-1');
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      await svc.login(email: 'a@b.com', password: 'pwd-12345');

      expect(wipeCalls, 0,
          reason: 'same-user re-login must keep Drift rows intact');
      verify(() => storage.saveLastUserId('u-1')).called(1);
    });

    test('login does NOT wipe on the very first device login', () async {
      int wipeCalls = 0;
      Future<void> wiper() async => wipeCalls++;
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      // Fresh install — no cached id. There is no previous account, so
      // there is nothing to wipe.
      when(() => storage.getLastUserId()).thenAnswer((_) async => null);
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      await svc.login(email: 'a@b.com', password: 'pwd-12345');

      expect(wipeCalls, 0, reason: 'first login must not wipe an empty DB');
    });

    test('register also wipes when a different user was last on device',
        () async {
      int wipeCalls = 0;
      Future<void> wiper() async => wipeCalls++;
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      when(() => storage.getLastUserId())
          .thenAnswer((_) async => 'OTHER-USER');
      when(() => dio.post('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      await svc.register(
        fullName: 'Ana B',
        phone: '+57 300',
        email: 'a@b.com',
        password: 'pwd-12345',
        privacyConsent: true,
      );

      expect(wipeCalls, 1,
          reason: 'registering a new account on a hand-me-down device wipes');
    });
  });

  // v1.9.8 — P0 fix. After a successful login/register, AuthService must
  // hydrate the local Drift DB by awaiting the injected `RemotePuller`.
  // The previous fire-and-forget seed in `AuthNotifier` raced with the
  // first dashboard render, leaving the screen empty after a same-user
  // re-login (where the wipe-on-logout had emptied Drift).
  group('remote hydration on login/register (P0)', () {
    test('login awaits the puller after persisting tokens', () async {
      int pullCalls = 0;
      final order = <String>[];
      Future<void> puller() async {
        pullCalls++;
        order.add('pull');
      }

      when(() => storage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenAnswer((_) async {
        order.add('saveTokens');
      });
      when(() => storage.saveLastUserId(any())).thenAnswer((_) async {
        order.add('saveLastUserId');
      });
      // v1.9.11 — the user snapshot is written between `saveLastUserId`
      // and the remote pull so the next cold start can short-circuit the
      // active probe even if the pull crashes.
      when(() => storage.saveUserSnapshot(any())).thenAnswer((_) async {
        order.add('saveUserSnapshot');
      });
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final svc = AuthService(api, storage, pullRemoteData: puller);
      await svc.login(email: 'a@b.com', password: 'pwd-12345');

      expect(pullCalls, 1, reason: 'puller must run exactly once per login');
      // Order: tokens persisted, last_user_id saved, snapshot saved, THEN
      // remote pull. Pulling before persisting last_user_id would lose
      // track of which user the freshly pulled rows belong to if the pull
      // crashed. Persisting the snapshot before the pull means a network
      // failure mid-pull still leaves the next cold start with a valid
      // offline-friendly entry path.
      expect(order, [
        'saveTokens',
        'saveLastUserId',
        'saveUserSnapshot',
        'pull',
      ]);
    });

    test('register awaits the puller after persisting tokens', () async {
      int pullCalls = 0;
      Future<void> puller() async => pullCalls++;

      when(() => dio.post('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final svc = AuthService(api, storage, pullRemoteData: puller);
      await svc.register(
        fullName: 'Ana',
        phone: '+57 300',
        email: 'a@b.com',
        password: 'pwd-12345',
        privacyConsent: true,
      );

      expect(pullCalls, 1,
          reason: 'puller must run exactly once per register');
    });

    test('login completes even when the puller throws (offline-tolerant)',
        () async {
      Future<void> puller() async => throw Exception('network down');

      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final svc = AuthService(api, storage, pullRemoteData: puller);

      // Must NOT throw — login completes, user reaches the dashboard,
      // SyncProvider auto-retries when connectivity returns.
      final auth = await svc.login(
        email: 'a@b.com',
        password: 'pwd-12345',
      );
      expect(auth.user.email, 'a@b.com');
    });

    test('login still works when no puller is injected (legacy callers)',
        () async {
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      // No `pullRemoteData` — the legacy unit-test constructor path
      // must keep working so the service stays pure-Dart-testable.
      final svc = AuthService(api, storage);
      final auth = await svc.login(
        email: 'a@b.com',
        password: 'pwd-12345',
      );
      expect(auth.user.email, 'a@b.com');
    });

    test(
        'cross-user wipe runs BEFORE the puller so we never pull into stale rows',
        () async {
      final order = <String>[];
      Future<void> wiper() async => order.add('wipe');
      Future<void> puller() async => order.add('pull');

      when(() => storage.getLastUserId())
          .thenAnswer((_) async => 'OTHER-USER');
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final svc = AuthService(
        api,
        storage,
        wipeLocalData: wiper,
        pullRemoteData: puller,
      );
      await svc.login(email: 'a@b.com', password: 'pwd-12345');

      // Wipe must run first; otherwise pulled rows could collide with
      // the previous user's residual rows under LWW.
      expect(order, ['wipe', 'pull']);
    });
  });

  // v1.11.x stale-state login bug: a recreated account (purge + re-register
  // → new user.id) hit the cross-user branch over stale local state and
  // threw, surfacing as the opaque "Ocurrió un error" with "Clear app data"
  // the only workaround. Local-setup failures must NOT abort an already-
  // authenticated session.
  group('self-healing local setup (v1.11.x stale-state bug)', () {
    test('login still completes + saves tokens when the cross-user wipe throws',
        () async {
      Future<void> wiper() async => throw StateError('drift wipe boom');
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      // Different cached id → the cross-user wipe branch fires (and throws).
      when(() => storage.getLastUserId()).thenAnswer((_) async => 'OLD-ID');
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final auth = await svc.login(email: 'a@b.com', password: 'pwd-12345');

      expect(auth.user.id, 'u-1', reason: 'auth succeeded; wipe failure swallowed');
      verify(() => storage.saveTokens(accessToken: 'acc', refreshToken: 'ref'))
          .called(1);
      verify(() => storage.saveLastUserId('u-1')).called(1);
    });

    test('login still completes when saveUserSnapshot throws', () async {
      when(() => storage.getLastUserId()).thenAnswer((_) async => null);
      when(() => storage.saveUserSnapshot(any()))
          .thenThrow(StateError('snapshot boom'));
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final auth = await service.login(email: 'a@b.com', password: 'pwd-12345');

      expect(auth.user.id, 'u-1');
      verify(() => storage.saveTokens(accessToken: 'acc', refreshToken: 'ref'))
          .called(1);
    });

    test('register still completes when the cross-user wipe throws', () async {
      Future<void> wiper() async => throw StateError('drift wipe boom');
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      when(() => storage.getLastUserId()).thenAnswer((_) async => 'OLD-ID');
      when(() => dio.post('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      final auth = await svc.register(
        fullName: 'Ana',
        phone: '+57 300',
        email: 'a@b.com',
        password: 'pwd-12345',
        privacyConsent: true,
      );

      expect(auth.user.id, 'u-1');
    });

    test('a genuine token-storage failure still propagates (not swallowed)',
        () async {
      when(() => storage.getLastUserId()).thenAnswer((_) async => null);
      when(() => storage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenThrow(StateError('keystore unavailable'));
      when(() => dio.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse(_authEnvelope()));

      expect(
        () => service.login(email: 'a@b.com', password: 'pwd-12345'),
        throwsA(isA<StateError>()),
        reason: 'token persistence is essential — must not be swallowed',
      );
    });
  });

  // v1.9.9 — P0 fix (continuation of v1.9.8). Logout must push any
  // local pending changes BEFORE wiping the Drift DB, otherwise a row
  // created in the session that has not yet been auto-synced is destroyed
  // before reaching the server. The push is bounded by a hard 5 s timeout
  // so a slow/offline backend cannot block logout.
  group('push-before-wipe on logout (P0)', () {
    test('logout pushes BEFORE wiping local data', () async {
      final order = <String>[];
      Future<void> pusher() async => order.add('push');
      Future<void> wiper() async => order.add('wipe');
      when(() => storage.getRefreshToken()).thenAnswer((_) async => 'R-X');
      when(() => storage.deleteAll()).thenAnswer((_) async {
        order.add('deleteAll');
      });
      when(() => dio.post('/auth/logout', data: any(named: 'data')))
          .thenAnswer((_) async => okResponse({'success': true}));

      final svc = AuthService(
        api,
        storage,
        wipeLocalData: wiper,
        pushPending: pusher,
      );
      await svc.logout();

      // Push runs first, then the server logout call, then secure storage
      // is cleared, then the Drift wipe runs. Any other order risks
      // destroying unsynced rows before they reach the server.
      expect(order, ['push', 'deleteAll', 'wipe']);
    });

    test('wipe still runs when the pusher throws', () async {
      int wipeCalls = 0;
      Future<void> pusher() async => throw Exception('network down');
      Future<void> wiper() async => wipeCalls++;
      when(() => storage.getRefreshToken()).thenAnswer((_) async => null);

      final svc = AuthService(
        api,
        storage,
        wipeLocalData: wiper,
        pushPending: pusher,
      );

      // Must NOT propagate — logout always completes and always wipes.
      await svc.logout();

      expect(wipeCalls, 1,
          reason: 'privacy invariant (wipe) wins over push failure');
      verify(() => storage.deleteAll()).called(1);
    });

    test('logout works without a pusher (legacy callers)', () async {
      int wipeCalls = 0;
      Future<void> wiper() async => wipeCalls++;
      when(() => storage.getRefreshToken()).thenAnswer((_) async => null);

      // No `pushPending` — must behave exactly like pre-v1.9.9.
      final svc = AuthService(api, storage, wipeLocalData: wiper);

      await svc.logout();

      expect(wipeCalls, 1);
      verify(() => storage.deleteAll()).called(1);
    });
  });
}
