import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:agritrace_mobile/navigation/route_names.dart';
import 'package:agritrace_mobile/screens/auth/welcome_screen.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
        GoRoute(
          path: Routes.login,
          builder: (_, __) => const Scaffold(body: Text('LoginPage')),
        ),
        GoRoute(
          path: Routes.register,
          builder: (_, __) => const Scaffold(body: Text('RegisterPage')),
        ),
      ],
    );

Widget _wrap() => ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    );

void main() {
  testWidgets('shows AgriTrace logo and tagline', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('AgriTrace'), findsOneWidget);
    expect(
      find.text('Certifica tus cultivos y accede a mercados premium'),
      findsOneWidget,
    );
  });

  testWidgets('shows login and register CTAs', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });

  testWidgets('tapping Iniciar sesión navigates to login', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('LoginPage'), findsOneWidget);
  });

  testWidgets('tapping register link navigates to register', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
    expect(find.text('RegisterPage'), findsOneWidget);
  });
}
