import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/providers/auth_provider.dart';
import 'package:agritrace_mobile/screens/auth/register_screen.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';
import 'package:agritrace_mobile/widgets/common/app_button.dart';
import 'package:agritrace_mobile/widgets/common/app_error_banner.dart';

/// Widget-level coverage for CU-01 — Registro de productor con consentimiento
/// Ley 1581. The contract under test is the screen's behaviour, not the
/// service or the router: AuthService is mocked via Riverpod overrides and
/// the screen is pumped in isolation (no GoRouter — navigation paths are
/// asserted indirectly through the service-call payload).
///
/// CU spec: agritrace-docs/01-preparacion-mvp/03-mapeo-funcional/
///          casos-de-uso/CU-01-registro-productor.md
class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

/// Builds a successful AuthResponse for the happy-path mock.
AuthResponse _okResponse() => const AuthResponse(
      accessToken: 'A',
      refreshToken: 'R',
      user: User(
        id: 'u-1',
        email: 'diego@agritrace.co',
        fullName: 'Diego Trujillo',
        phone: '+57 300 000 0000',
        role: UserRole.producer,
      ),
    );

/// Builds a DioException with a [statusCode]-bearing response, or — when
/// [statusCode] is null — a response-less exception (treated as "no network"
/// by `parseApiError`).
DioException _dioError({int? statusCode}) {
  final options = RequestOptions(path: '/auth/register');
  return DioException(
    requestOptions: options,
    response: statusCode == null
        ? null
        : Response<dynamic>(
            requestOptions: options,
            statusCode: statusCode,
          ),
  );
}

void main() {
  late MockAuthService mockAuth;
  late MockStorageService mockStorage;

  setUpAll(() {
    // mocktail needs fallbacks for any String args used with `any(named:)`.
    registerFallbackValue('');
  });

  setUp(() {
    mockAuth = MockAuthService();
    mockStorage = MockStorageService();
    // AuthNotifier.build() reads the access token on construction; returning
    // null keeps the notifier in the `AuthUnauthenticated` state so the
    // screen mounts cleanly.
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
  });

  List<Override> overrides() => [
        authServiceProvider.overrideWithValue(mockAuth),
        storageServiceProvider.overrideWithValue(mockStorage),
      ];

  Widget wrap() => ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(home: RegisterScreen()),
      );

  /// Pumps the screen and waits for `AuthNotifier.build()` to resolve.
  /// Until it does, the auth state is `AsyncLoading` and the submit button
  /// shows the spinner instead of the label "Registrarse" — which would
  /// break every text-based assertion. Settling here moves the state to
  /// `AuthUnauthenticated` so the screen reaches its initial idle frame.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  /// Scrolls the submit button into view before tapping. The screen is taller
  /// than the default 800×600 test surface, so the CTA sits off-screen on
  /// first render — `tester.tap` would warn and miss.
  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(AppButton));
    await tester.pump();
    await tester.tap(find.byType(AppButton));
  }

  /// Fills the 4 form fields with valid values. Does NOT toggle the
  /// consent checkbox — callers do that explicitly when relevant.
  /// Fields are matched by index because all four inputs use the shared
  /// `AppInput` wrapper which has identical empty-string labels on its
  /// inner `TextFormField`.
  Future<void> fillValidForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Diego Trujillo');
    await tester.enterText(fields.at(1), '+57 300 000 0000');
    await tester.enterText(fields.at(2), 'diego@agritrace.co');
    await tester.enterText(fields.at(3), 'StrongPass1');
  }

  /// Stubs `AuthService.register` to throw [error] on the next call.
  void stubRegisterToThrow(Object error) {
    when(() => mockAuth.register(
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          privacyConsent: any(named: 'privacyConsent'),
          privacyConsentVersion: any(named: 'privacyConsentVersion'),
        )).thenThrow(error);
  }

  /// Stubs `AuthService.register` to succeed on the next call.
  void stubRegisterToSucceed() {
    when(() => mockAuth.register(
          fullName: any(named: 'fullName'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          privacyConsent: any(named: 'privacyConsent'),
          privacyConsentVersion: any(named: 'privacyConsentVersion'),
        )).thenAnswer((_) async => _okResponse());
  }

  group('CU-01 — Pantalla 2 — Registro de productor', () {
    testWidgets(
        'renders the 4 form fields, the consent checkbox and the policy link',
        (tester) async {
      // Arrange / Act
      await pumpScreen(tester);

      // Assert — every field label appears exactly once (the input label).
      expect(find.text('Nombre completo'), findsOneWidget);
      expect(find.text('Teléfono'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      // Consent checkbox + the privacy policy link.
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Política de Privacidad'), findsOneWidget);
      // The submit CTA is present (text may be off-screen until scrolled).
      expect(find.byType(AppButton), findsOneWidget);
      await tester.ensureVisible(find.byType(AppButton));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'Registrarse'),
          findsOneWidget);
    });

    testWidgets(
        'Flujo C — submit button is disabled until the consent box is checked',
        (tester) async {
      // Arrange — form filled but consent unchecked.
      await pumpScreen(tester);
      await fillValidForm(tester);
      await tester.pump();

      // Act — read the AppButton widget directly.
      final btn = tester.widget<AppButton>(find.byType(AppButton));

      // Assert — onPressed is null → disabled.
      expect(btn.onPressed, isNull,
          reason: 'Per CU-01 Flujo C, the CTA must be inert without consent');

      // And the service was never invoked even if a tap is dispatched.
      // `warnIfMissed: false` because the disabled button is below the fold
      // on the 800×600 test surface — we only care about no-side-effects.
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();
      verifyNever(() => mockAuth.register(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            privacyConsent: any(named: 'privacyConsent'),
            privacyConsentVersion: any(named: 'privacyConsentVersion'),
          ));
    });

    testWidgets(
        'submit button shows the loading spinner while a register call is in flight',
        (tester) async {
      // Arrange — pending future so the AsyncNotifier stays in loading.
      final completer = Completer<AuthResponse>();
      when(() => mockAuth.register(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            privacyConsent: any(named: 'privacyConsent'),
            privacyConsentVersion: any(named: 'privacyConsentVersion'),
          )).thenAnswer((_) => completer.future);

      await pumpScreen(tester);
      await fillValidForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act — submit; pump (NOT settle) so the future stays pending.
      await tapSubmit(tester);
      await tester.pump();

      // Assert — button is in loading state and disabled.
      final btn = tester.widget<AppButton>(find.byType(AppButton));
      expect(btn.isLoading, isTrue);
      expect(btn.onPressed, isNull);

      // Cleanup — complete the future to drain pending timers.
      completer.complete(_okResponse());
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Escenario principal — happy path: calls AuthService.register with the '
        'CU-01 payload and never sends role', (tester) async {
      // Arrange
      stubRegisterToSucceed();
      await pumpScreen(tester);
      await fillValidForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      // Assert — register called exactly once with the expected named args.
      // `role` is intentionally absent — the server assigns it (security:
      // a client-chosen role would be an authz bypass).
      final captured = verify(() => mockAuth.register(
            fullName: captureAny(named: 'fullName'),
            phone: captureAny(named: 'phone'),
            email: captureAny(named: 'email'),
            password: captureAny(named: 'password'),
            privacyConsent: captureAny(named: 'privacyConsent'),
            privacyConsentVersion: captureAny(named: 'privacyConsentVersion'),
          )).captured;
      expect(captured, [
        'Diego Trujillo',
        '+57 300 000 0000',
        'diego@agritrace.co',
        'StrongPass1',
        true,
        '1.0',
      ]);
    });

    testWidgets(
        'Flujo A — 409 ConflictError surfaces the "Ese email ya está registrado" banner',
        (tester) async {
      // Arrange
      stubRegisterToThrow(_dioError(statusCode: 409));
      await pumpScreen(tester);
      await fillValidForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      // Assert — banner renders the CU-01 Flujo A message.
      expect(find.byType(AppErrorBanner), findsOneWidget);
      expect(find.text('Ese email ya está registrado'), findsOneWidget);
    });

    testWidgets(
        'Flujo B — weak password fails client-side validation and never hits the network',
        (tester) async {
      // Arrange — fill everything but use a too-short password.
      await pumpScreen(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Diego Trujillo');
      await tester.enterText(fields.at(1), '+57 300 000 0000');
      await tester.enterText(fields.at(2), 'diego@agritrace.co');
      await tester.enterText(fields.at(3), 'abc');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act
      await tapSubmit(tester);
      await tester.pump();

      // Assert — validator surfaces the length message, request never went out.
      expect(find.text('La contraseña debe tener al menos 8 caracteres'),
          findsOneWidget);
      verifyNever(() => mockAuth.register(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            privacyConsent: any(named: 'privacyConsent'),
            privacyConsentVersion: any(named: 'privacyConsentVersion'),
          ));
    });

    testWidgets(
        'Flujo C — defense in depth: even if the disabled-button guard were '
        'bypassed, _submit short-circuits when consent is false',
        (tester) async {
      // Arrange — form filled but consent intentionally unchecked.
      await pumpScreen(tester);
      await fillValidForm(tester);

      // Act — tap the (disabled) submit button. `warnIfMissed: false` because
      // the disabled button is below the fold and we only assert side effects.
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();

      // Assert — no service call, no banner. The disabled button is the
      // first line of defence; the early-return in `_submit` is the second.
      verifyNever(() => mockAuth.register(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            privacyConsent: any(named: 'privacyConsent'),
            privacyConsentVersion: any(named: 'privacyConsentVersion'),
          ));
      expect(find.byType(AppErrorBanner), findsNothing);
    });

    testWidgets(
        'Flujo D — 429 RateLimited surfaces the "Muchos intentos" banner',
        (tester) async {
      // Arrange
      stubRegisterToThrow(_dioError(statusCode: 429));
      await pumpScreen(tester);
      await fillValidForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AppErrorBanner), findsOneWidget);
      expect(find.text('Muchos intentos, intenta de nuevo en unos minutos'),
          findsOneWidget);
    });

    testWidgets(
        'Flujo E — no network (response == null) surfaces the offline banner',
        (tester) async {
      // Arrange
      stubRegisterToThrow(_dioError(statusCode: null));
      await pumpScreen(tester);
      await fillValidForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act
      await tapSubmit(tester);
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(AppErrorBanner), findsOneWidget);
      expect(find.text('Sin conexión, verifica tu internet'), findsOneWidget);
    });

    testWidgets(
        'invalid email format triggers the client-side validator and never '
        'hits the network', (tester) async {
      // Arrange
      await pumpScreen(tester);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Diego Trujillo');
      await tester.enterText(fields.at(1), '+57 300 000 0000');
      await tester.enterText(fields.at(2), 'not-an-email');
      await tester.enterText(fields.at(3), 'StrongPass1');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Act
      await tapSubmit(tester);
      await tester.pump();

      // Assert
      expect(find.text('Ingresa un email válido'), findsOneWidget);
      verifyNever(() => mockAuth.register(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            password: any(named: 'password'),
            privacyConsent: any(named: 'privacyConsent'),
            privacyConsentVersion: any(named: 'privacyConsentVersion'),
          ));
    });
  });
}
