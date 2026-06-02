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
import '../screens/pilot/pilot_blocked_screen.dart';
import '../models/user.dart';
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

      final authValue = authState.valueOrNull;
      final authenticatedState = authValue is AuthAuthenticated ? authValue : null;
      final isAuthenticated = authenticatedState != null;
      final loc = state.matchedLocation;

      final isAuthRoute = {
        Routes.welcome,
        Routes.login,
        Routes.register,
      }.contains(loc);

      if (!isAuthenticated && !isAuthRoute) return Routes.welcome;
      if (isAuthenticated && isAuthRoute) return Routes.dashboard;

      // Pilot-window gate. Checked after auth so only authenticated users
      // reach this branch. Admin role and is_demo users are always exempt.
      if (isAuthenticated) {
        final user = authenticatedState.user;
        final blocked = _isPilotBlocked(user);
        if (blocked && loc != Routes.pilotBlocked) return Routes.pilotBlocked;
        // When the operator extends/starts the pilot, let the user back in.
        if (!blocked && loc == Routes.pilotBlocked) return Routes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(path: Routes.welcome,   builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: Routes.login,     builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register,  builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.dashboard, builder: (_, __) => const DashboardScreen()),
      GoRoute(path: Routes.profile,   builder: (_, __) => const ProfileScreen()),
      GoRoute(path: Routes.pilotBlocked, builder: (_, __) => const PilotBlockedScreen()),
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
        // `extra` (when set) is the free-text cropType the producer typed
        // on the farm form — used to pre-select the plot dropdown when
        // arriving via the post-create-finca auto-navigation flow.
        builder: (_, state) => PlotFormScreen(
          farmId: state.pathParameters['farmId']!,
          initialCropTypeSuggestion: state.extra as String?,
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

/// Returns true when [user] must be redirected to [Routes.pilotBlocked].
///
/// Exempt: admin role, is_demo flag.
/// Blocked: pilot not started (pilotEndsAt null) or window elapsed.
bool _isPilotBlocked(User user) {
  if (user.role == UserRole.admin || user.isDemo) return false;
  final endsAt = user.pilotEndsAt;
  if (endsAt == null) return true;
  return DateTime.now().isAfter(endsAt);
}

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
