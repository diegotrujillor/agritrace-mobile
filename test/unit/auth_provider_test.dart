import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/providers/auth_provider.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';

class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}

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

// JWT with `{"exp": 9999999999}` (year 2286). The signature is irrelevant
// because cold-start validation only checks shape + `exp` claim.
const _futureJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjk5OTk5OTk5OTl9.sig';

// JWT with `{"exp": 1}` (1970). Used to verify the cold-start path rejects
// expired tokens.
const _expiredJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjF9.sig';

void main() {
  late MockAuthService mockAuth;
  late MockStorageService mockStorage;

  setUp(() {
    mockAuth    = MockAuthService();
    mockStorage = MockStorageService();
    // deleteTokens() is called whenever the cold-start validator rejects
    // a stored token. Always stub it to a no-op so mocktail does not throw.
    when(() => mockStorage.deleteTokens()).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuth),
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

  test('initial state is unauthenticated when no token stored', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
  });

  test('initial state is authenticated when a valid JWT is stored', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => _futureJwt);
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthAuthenticated>());
  });

  test('initial state is unauthenticated when stored token is malformed', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => 'not-a-jwt');
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
    verify(() => mockStorage.deleteTokens()).called(1);
  });

  test('initial state is unauthenticated when stored token has expired', () async {
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => _expiredJwt);
    final container = makeContainer();
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    expect(container.read(authProvider).value, isA<AuthUnauthenticated>());
    verify(() => mockStorage.deleteTokens()).called(1);
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
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => _futureJwt);
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
