import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/navigation/route_names.dart';
import 'package:agritrace_mobile/providers/auth_provider.dart';
import 'package:agritrace_mobile/screens/auth/login_screen.dart';
import 'package:agritrace_mobile/services/auth_service.dart';
import 'package:agritrace_mobile/services/storage_service.dart';

class MockAuthService extends Mock implements AuthService {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockAuthService mockAuth;
  late MockStorageService mockStorage;

  setUp(() {
    mockAuth    = MockAuthService();
    mockStorage = MockStorageService();
    when(() => mockStorage.getAccessToken()).thenAnswer((_) async => null);
  });

  List<Override> overrides() => [
        authServiceProvider.overrideWithValue(mockAuth),
        storageServiceProvider.overrideWithValue(mockStorage),
      ];

  GoRouter router() => GoRouter(
        initialLocation: Routes.login,
        routes: [
          GoRoute(path: Routes.login,    builder: (_, __) => const LoginScreen()),
          GoRoute(path: Routes.register, builder: (_, __) => const Scaffold(body: Text('RegisterPage'))),
          GoRoute(path: Routes.dashboard, builder: (_, __) => const Scaffold(body: Text('DashboardPage'))),
        ],
      );

  Widget wrap() => ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(routerConfig: router()),
      );

  testWidgets('shows email and password fields', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('shows validation errors when submitting empty form',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('El email es requerido'), findsOneWidget);
    expect(find.text('La contraseña es requerida'), findsOneWidget);
  });

  testWidgets('navigates to register on link tap', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.text('RegisterPage'), findsOneWidget);
  });
}
