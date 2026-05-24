import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';

import '_helpers.dart';

class _MockStorageService extends Mock implements StorageService {}

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
}
