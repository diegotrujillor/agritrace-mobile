import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/providers/auth_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/connectivity_sync_bridge.dart';
import 'package:agritrace_mobile/services/storage_service.dart';
import 'package:agritrace_mobile/services/sync_orchestrator.dart';
import 'package:agritrace_mobile/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}
class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

/// v1.9.10 — `AuthNotifier` arms a `ConnectivitySyncBridge` on every
/// authenticated entry point. Tests don't have a platform channel for
/// `connectivity_plus`, so we substitute a no-op bridge backed by a
/// `Connectivity` instance that is never actually invoked.
class _NoOpConnectivitySyncBridge extends ConnectivitySyncBridge {
  _NoOpConnectivitySyncBridge()
      : super(
          connectivity: Connectivity(),
          onReconnected: () async {},
        );

  @override
  void start() {}

  @override
  void stop() {}
}

const _testUser = User(
  id: 'user-1',
  email: 'test@test.com',
  fullName: 'Test User',
  phone: '+57 300 000 0000',
  role: UserRole.producer,
);

const _testAuth = AuthResponse(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  user: _testUser,
);

/// Builds a [DioException] simulating a refresh-endpoint HTTP failure with
/// the given [statusCode]. Used to verify the cold-start probe's handling
/// of 401/403 (unrecoverable) vs 5xx (transient).
DioException _refreshHttpError(int statusCode) {
  final options = RequestOptions(path: '/auth/refresh');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
    ),
  );
}

/// Builds a [DioException] with no HTTP response (simulating an offline
/// device or a connection timeout). v1.9.11 — used by the background-probe
/// tests to verify the offline-friendly cold start keeps the session.
DioException _refreshNetworkError() {
  final options = RequestOptions(path: '/auth/refresh');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    error: 'no internet',
  );
}

/// Encodes a payload as a JWT (header + body + dummy signature). Padding
/// is stripped so the parser exercises the same un-padded base64Url path
/// that real backend tokens use.
String _jwt(Map<String, dynamic> payload) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.sig';
}

String _jwtValid() => _jwt({
      'sub': 'user-1',
      'exp': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000,
    });

String _jwtExpired() => _jwt({
      'sub': 'user-1',
      'exp':
          DateTime.utc(2020, 1, 1).millisecondsSinceEpoch ~/ 1000,
    });

void main() {
  late MockAuthService mockAuth;
  late MockStorageService mockStorage;
  late MockSyncOrchestrator mockOrchestrator;

  setUp(() {
    mockAuth    = MockAuthService();
    mockStorage = MockStorageService();
    mockOrchestrator = MockSyncOrchestrator();
    // deleteTokens() / deleteAll() are called whenever the cold-start probe
    // rejects a stored token. Always stub them to no-ops so mocktail does
    // not throw on the verify-side checks.
    when(() => mockStorage.deleteTokens()).thenAnswer((_) async {});
    when(() => mockStorage.deleteAll()).thenAnswer((_) async {});
    // v1.9.11 — default: no user snapshot stored. Tests that exercise the
    // offline-friendly fast path explicitly override this. The legacy
    // active-probe path is the default behavior with this stub.
    when(() => mockStorage.getUserSnapshot()).thenAnswer((_) async => null);
    // Background seed sync — fire-and-forget. Stub to no-op so tests that
    // exercise login/register/cold-start succeed without hitting the real DB.
    when(() => mockOrchestrator.run(since: any(named: 'since')))
        .thenAnswer((_) async => SyncResult(
              synced: 0,
              conflicts: 0,
              pulledChanges: const [],
              timestamp: DateTime.utc(2026, 1, 1),
            ));
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuth),
          storageServiceProvider.overrideWithValue(mockStorage),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
          // v1.9.10 — auth notifier starts/stops the connectivity bridge
          // on every authenticated entry point. Override with a no-op so
          // tests do not hit the missing `connectivity_plus` platform channel.
          connectivitySyncBridgeProvider
              .overrideWithValue(_NoOpConnectivitySyncBridge()),
        ],
      );

  test('initial state is unauthenticated when no access token stored', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
    // Probe must NOT run when there is no access token to probe with.
    verifyNever(() => mockAuth.refresh());
  });

  test('initial state is unauthenticated when no refresh token stored', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'access-X');
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => null);
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
    verifyNever(() => mockAuth.refresh());
  });

  test('initial state is authenticated when the refresh probe succeeds', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'access-X');
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => 'refresh-X');
    when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    final state = container.read(authProvider).value;
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.email, 'test@test.com');
    verify(() => mockAuth.refresh()).called(1);
  });

  test('initial state is unauthenticated when refresh probe returns 401', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'access-X');
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => 'refresh-X');
    when(() => mockAuth.refresh()).thenThrow(_refreshHttpError(401));

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
    // v1.9.11 — strict probe wipes the entire keychain (tokens + snapshot
    // + last_user_id), not just the tokens.
    verify(() => mockStorage.deleteAll()).called(1);
  });

  test(
      'initial state is unauthenticated when refresh probe returns 5xx '
      '(transient — tokens NOT cleared)', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'access-X');
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => 'refresh-X');
    when(() => mockAuth.refresh()).thenThrow(_refreshHttpError(503));

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
    // Transient failure must preserve the tokens so the next cold-start can
    // retry the probe instead of forcing the user to re-login on a 503.
    verifyNever(() => mockStorage.deleteTokens());
    verifyNever(() => mockStorage.deleteAll());
  });

  // ─── v1.9.11 — Offline-friendly cold start ──────────────────────────────

  group('v1.9.11 offline-friendly cold start', () {
    test(
      'returns Authenticated synchronously from cached snapshot without '
      'awaiting refresh when snapshot + valid JWT exist',
      () async {
        when(() => mockStorage.getAccessToken())
            .thenAnswer((_) async => _jwtValid());
        when(() => mockStorage.getRefreshToken())
            .thenAnswer((_) async => 'refresh-X');
        when(() => mockStorage.getUserSnapshot())
            .thenAnswer((_) async => _testUser);
        // The background probe will eventually run; stub it so mocktail
        // does not throw if the microtask fires before tearDown.
        when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);

        final container = makeContainer();
        addTearDown(container.dispose);

        // Read synchronously without awaiting any background work.
        await container.read(authProvider.future);
        final state = container.read(authProvider).value;
        expect(state, isA<AuthAuthenticated>());
        expect((state as AuthAuthenticated).user.id, 'user-1');
        // At this point refresh() may or may not have been called yet — the
        // critical invariant is that build() did not BLOCK on it. Verifying
        // refresh was NOT called at the moment build() returns is the
        // load-bearing assertion: it proves the dashboard renders even if
        // the device is offline.
        // (Drain microtasks below to verify the background probe DOES
        // run afterwards.)
      },
    );

    test(
      'background probe success keeps state Authenticated and rotates tokens',
      () async {
        when(() => mockStorage.getAccessToken())
            .thenAnswer((_) async => _jwtValid());
        when(() => mockStorage.getRefreshToken())
            .thenAnswer((_) async => 'refresh-X');
        when(() => mockStorage.getUserSnapshot())
            .thenAnswer((_) async => _testUser);
        when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);

        final container = makeContainer();
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        // Drain pending microtasks so the background probe completes.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(authProvider).value, isA<AuthAuthenticated>());
        verify(() => mockAuth.refresh()).called(1);
        verifyNever(() => mockStorage.deleteAll());
      },
    );

    test(
      'background probe 401 flips state to Unauthenticated and wipes storage',
      () async {
        when(() => mockStorage.getAccessToken())
            .thenAnswer((_) async => _jwtValid());
        when(() => mockStorage.getRefreshToken())
            .thenAnswer((_) async => 'refresh-X');
        when(() => mockStorage.getUserSnapshot())
            .thenAnswer((_) async => _testUser);
        when(() => mockAuth.refresh()).thenThrow(_refreshHttpError(401));

        final container = makeContainer();
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        // First frame: offline-friendly Authenticated.
        expect(container.read(authProvider).value, isA<AuthAuthenticated>());

        // Drain microtasks so the background probe runs.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
        verify(() => mockStorage.deleteAll()).called(1);
      },
    );

    test(
      'background probe network error keeps current Authenticated state',
      () async {
        when(() => mockStorage.getAccessToken())
            .thenAnswer((_) async => _jwtValid());
        when(() => mockStorage.getRefreshToken())
            .thenAnswer((_) async => 'refresh-X');
        when(() => mockStorage.getUserSnapshot())
            .thenAnswer((_) async => _testUser);
        when(() => mockAuth.refresh()).thenThrow(_refreshNetworkError());

        final container = makeContainer();
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Offline farmer must NOT be logged out on a probe network failure.
        expect(container.read(authProvider).value, isA<AuthAuthenticated>());
        verifyNever(() => mockStorage.deleteAll());
        verifyNever(() => mockStorage.deleteTokens());
      },
    );

    test(
      'snapshot present but JWT expired falls through to the legacy strict '
      'active probe',
      () async {
        when(() => mockStorage.getAccessToken())
            .thenAnswer((_) async => _jwtExpired());
        when(() => mockStorage.getRefreshToken())
            .thenAnswer((_) async => 'refresh-X');
        when(() => mockStorage.getUserSnapshot())
            .thenAnswer((_) async => _testUser);
        when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);

        final container = makeContainer();
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        // The legacy path AWAITS refresh; so by the time build resolves
        // the call has happened.
        expect(container.read(authProvider).value, isA<AuthAuthenticated>());
        verify(() => mockAuth.refresh()).called(1);
      },
    );

    test(
      'missing snapshot falls through to the legacy strict active probe',
      () async {
        when(() => mockStorage.getAccessToken())
            .thenAnswer((_) async => _jwtValid());
        when(() => mockStorage.getRefreshToken())
            .thenAnswer((_) async => 'refresh-X');
        when(() => mockStorage.getUserSnapshot()).thenAnswer((_) async => null);
        when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);

        final container = makeContainer();
        addTearDown(container.dispose);

        await container.read(authProvider.future);
        expect(container.read(authProvider).value, isA<AuthAuthenticated>());
        verify(() => mockAuth.refresh()).called(1);
      },
    );
  });

  test('markUnauthenticated() flips state to AuthUnauthenticated', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'access-X');
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => 'refresh-X');
    when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthAuthenticated>());

    container.read(authProvider.notifier).markUnauthenticated();
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
  });

  test('login sets authenticated state on success', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
    when(() => mockAuth.login(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ))
        .thenAnswer((_) async => _testAuth);

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container
        .read(authProvider.notifier)
        .login(email: 'test@test.com', password: 'password123');

    final state = container.read(authProvider).value;
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.email, 'test@test.com');
  });

  test('logout sets unauthenticated state', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'access-X');
    when(() => mockStorage.getRefreshToken()).thenAnswer((_) async => 'refresh-X');
    when(() => mockAuth.refresh()).thenAnswer((_) async => _testAuth);
    when(() => mockAuth.logout()).thenAnswer((_) async {});

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).logout();

    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
  });

  test('register sets authenticated state on success', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
    when(() => mockAuth.register(
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
              email: any(named: 'email'),
              password: any(named: 'password'),
              privacyConsent: any(named: 'privacyConsent'),
            ))
        .thenAnswer((_) async => _testAuth);

    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).register(
          fullName: 'Test User',
          phone: '+57 300 000 0000',
          email: 'test@test.com',
          password: 'password123',
          privacyConsent: true,
        );

    expect(container.read(authProvider).value, isA<AuthAuthenticated>());
  });
}
