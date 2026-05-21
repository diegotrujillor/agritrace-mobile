import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/providers/auth_provider.dart';
import 'package:agritrace_mobile/providers/database_provider.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';
import 'package:agritrace_mobile/services/sync_orchestrator.dart';
import 'package:agritrace_mobile/services/sync_service.dart';

class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}
class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

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

void main() {
  late MockAuthService mockAuth;
  late MockStorageService mockStorage;
  late MockSyncOrchestrator mockOrchestrator;

  setUp(() {
    mockAuth    = MockAuthService();
    mockStorage = MockStorageService();
    mockOrchestrator = MockSyncOrchestrator();
    // deleteTokens() is called whenever the cold-start probe rejects
    // a stored token. Always stub it to a no-op so mocktail does not throw.
    when(() => mockStorage.deleteTokens()).thenAnswer((_) async {});
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
    verify(() => mockStorage.deleteTokens()).called(1);
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
