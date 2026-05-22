import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/farm.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/farms/dashboard_screen.dart';
import '../screens/farms/farm_detail_screen.dart';
import '../screens/farms/farm_form_screen.dart';
import '../screens/plots/plot_detail_screen.dart';
import '../screens/plots/plot_edit_screen.dart';
import '../screens/plots/plot_form_screen.dart';
import '../screens/activities/activity_edit_screen.dart';
import '../screens/activities/activity_form_screen.dart';
import '../screens/activities/activity_timeline_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/alerts/alert_form_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'route_names.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthListenable(ref);
  ref.onDispose(notifier.dispose);

  final router = GoRouter(
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
      GoRoute(path: Routes.profile,   builder: (_, __) => const ProfileScreen()),
      // Static `/alerts/new` before `/alerts` for consistency with the
      // `/new`-before-`:id` ordering used elsewhere.
      GoRoute(path: Routes.alertNew, builder: (_, __) => const AlertFormScreen()),
      GoRoute(path: Routes.alerts,   builder: (_, __) => const AlertsScreen()),
      // Static / more-specific paths are declared before `/farms/:id` so the
      // `:id` segment never captures `new` or the nested plots paths.
      GoRoute(
        path: Routes.farmsNew,
        // `extra` carries a Farm when navigating in edit mode; null = create.
        builder: (_, state) => FarmFormScreen(farm: state.extra as Farm?),
      ),
      GoRoute(
        path: Routes.plotNewPath,
        builder: (_, state) => PlotFormScreen(
          farmId: state.pathParameters['farmId']!,
        ),
      ),
      // Activity routes use a `:plotId` segment and are declared before
      // `/plots/:id` so the static `/activities` / `/activities/new` tails
      // are matched as activity routes, never as a plot id.
      GoRoute(
        path: Routes.activityNewPath,
        builder: (_, state) => ActivityFormScreen(
          plotId: state.pathParameters['plotId']!,
        ),
      ),
      GoRoute(
        path: Routes.activityTimelinePath,
        builder: (_, state) => ActivityTimelineScreen(
          plotId: state.pathParameters['plotId']!,
        ),
      ),
      // Activity edit lives on the flat `/activities/:id/edit` collection.
      // There is currently no other `/activities/:id` route, but the static
      // `/edit` tail keeps the path unambiguous if we ever add one.
      GoRoute(
        path: Routes.activityEditPath,
        builder: (_, state) => ActivityEditScreen(
          activityId: state.pathParameters['id']!,
        ),
      ),
      // Static `/edit` segment declared before `/plots/:id` so it is matched
      // as the edit route and never swallowed by the `:id` capture.
      GoRoute(
        path: Routes.plotEditPath,
        builder: (_, state) => PlotEditScreen(
          plotId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.plotDetailPath,
        builder: (_, state) => PlotDetailScreen(
          plotId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.farmDetailPath,
        builder: (_, state) => FarmDetailScreen(
          farmId: state.pathParameters['id']!,
        ),
      ),
    ],
  );

  // Dispose GoRouter when the provider is torn down to free its internal
  // RouteInformationProvider and RouterDelegate.
  ref.onDispose(router.dispose);
  return router;
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
