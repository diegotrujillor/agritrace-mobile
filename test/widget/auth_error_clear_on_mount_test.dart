// v1.9.4 — QA hotfix coverage for FIX #5 (Pantalla 19 in the v1.9.3
// user-feedback captures): a failed login on the login screen used to leak
// its "Credenciales incorrectas" banner onto the register screen because
// `authProvider` kept the AsyncError across the GoRouter navigation. The
// fix is in `_LoginScreenState.initState` and `_RegisterScreenState.initState`:
// both schedule `ref.read(authProvider.notifier).clearError()` via a
// post-frame callback so the banner is wiped the moment the screen mounts.
//
// These tests pump each screen with the auth notifier pre-seeded to an
// AsyncError and assert that no banner is rendered after `pumpAndSettle`.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/providers/auth_provider.dart';
import 'package:agritrace_mobile/screens/auth/login_screen.dart';
import 'package:agritrace_mobile/screens/auth/register_screen.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';
import 'package:agritrace_mobile/widgets/common/app_error_banner.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockStorageService extends Mock implements StorageService {}

/// Builds a DioException that mimics a 401 from `/auth/login` so the
/// resulting `parseApiError` output is the exact "Credenciales incorrectas"
/// string the screens render in their banner. We intentionally exercise the
/// login-shaped error to model the cross-screen leak the user reported.
DioException _wrongCredentialsError() {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 401,
    ),
  );
}

void main() {
  late _MockAuthService mockAuth;
  late _MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    mockAuth = _MockAuthService();
    mockStorage = _MockStorageService();
    // AuthNotifier.build() reads the access token on construction; return
    // null so the notifier finishes in `AuthUnauthenticated` and is ready
    // to receive a follow-up failed login that we then leak across screens.
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
    // Stub login to throw the 401 once when the test drives the leak.
    when(() => mockAuth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(_wrongCredentialsError());
  });

  List<Override> overrides() => [
        authServiceProvider.overrideWithValue(mockAuth),
        storageServiceProvider.overrideWithValue(mockStorage),
      ];

  /// Drives `AuthNotifier.login` with bad credentials so the notifier's
  /// state lands in `AsyncError`. This is the precondition the mount-clear
  /// fix has to neutralize on the next screen.
  Future<void> seedAuthError(ProviderContainer container) async {
    // The notifier swallows the throw inside `AsyncValue.guard`, so this
    // future never errors — it just settles with the state in AsyncError.
    await container.read(authProvider.notifier).login(
          email: 'wrong@example.com',
          password: 'BadPass123',
        );
    // Sanity check — we cannot continue if the seeding step did not
    // actually park the notifier in an error state.
    expect(container.read(authProvider).hasError, isTrue,
        reason: 'seed step failed: notifier is not in AsyncError');
  }

  testWidgets(
      'RegisterScreen wipes a stale auth error from the previous login attempt '
      'so the banner does not leak across screens',
      (tester) async {
    // Arrange — provider container we can drive directly (mirrors what the
    // GoRouter navigation flow leaves behind when the user taps "Regístrate"
    // after a failed login).
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    // Settle the AuthNotifier's `build()` so it leaves AsyncLoading.
    await container.read(authProvider.future);
    await seedAuthError(container);

    // Act — mount the register screen against the already-errored notifier.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    // `pumpAndSettle` lets the post-frame callback in `initState` run
    // `clearError()` before we assert.
    await tester.pumpAndSettle();

    // Assert — banner is gone, notifier is back in AsyncData.
    expect(find.byType(AppErrorBanner), findsNothing,
        reason: 'stale auth error leaked onto register screen');
    expect(container.read(authProvider).hasError, isFalse,
        reason: 'clearError() did not run on mount');
  });

  testWidgets(
      'LoginScreen also wipes a stale auth error on mount (symmetry with '
      'RegisterScreen so a back-navigation does not re-surface the banner)',
      (tester) async {
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await container.read(authProvider.future);
    await seedAuthError(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorBanner), findsNothing,
        reason: 'stale auth error survived a re-mount of LoginScreen');
    expect(container.read(authProvider).hasError, isFalse);
  });
}
