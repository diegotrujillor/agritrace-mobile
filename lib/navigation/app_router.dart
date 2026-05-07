import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/farms/dashboard_screen.dart';
import 'route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthListenable(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: Routes.welcome,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;
      final isAuthenticated = authState.valueOrNull is AuthAuthenticated;
      final isAuthRoute = {
        Routes.welcome,
        Routes.login,
        Routes.register,
      }.contains(state.matchedLocation);

      if (isAuthenticated && isAuthRoute)  return Routes.dashboard;
      if (!isAuthenticated && !isAuthRoute) return Routes.welcome;
      return null;
    },
    routes: [
      GoRoute(path: Routes.welcome,   builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.login,     builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register,  builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.dashboard, builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: Routes.farmsNew,
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Sprint 2 — Registrar finca')),
        ),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _sub = ref.listen<AsyncValue<AuthState>>(authProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
