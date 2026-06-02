import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'services/inactivity_monitor.dart';
import 'utils/theme.dart';
import 'widgets/common/pilot_countdown_banner.dart';

void main() {
  // Block google_fonts from making outbound HTTP requests to fonts.gstatic.com.
  // Ley 1581: don't leak farmer IPs to Google CDN. Offline-first rural
  // environment cannot rely on a CDN anyway — fonts must be bundled.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: AgriTraceApp()));
}

class AgriTraceApp extends ConsumerStatefulWidget {
  const AgriTraceApp({super.key});

  @override
  ConsumerState<AgriTraceApp> createState() => _AgriTraceAppState();
}

/// v1.9.8 — P1 fix. The app shell is now a [ConsumerStatefulWidget] so it
/// can observe [AppLifecycleState] transitions (foreground ↔ background)
/// and drive the shared [InactivityMonitor]. The widget also wraps the
/// router in a root-level [Listener] that pokes the monitor on every
/// pointer event, and watches the auth state to surface a
/// "Sesión cerrada por inactividad" SnackBar via a global
/// [ScaffoldMessenger].
class _AgriTraceAppState extends ConsumerState<AgriTraceApp>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Route lifecycle transitions to the inactivity monitor so a long
    // background trip is treated the same as foreground idleness. We use
    // `DateTime.now()` (not a monotonic clock) because the wall clock is
    // what the user perceives — a 20 min nap is 20 min regardless of
    // device clock drift.
    final monitor = ref.read(inactivityMonitorProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        monitor.markBackgroundedAt(DateTime.now());
      case AppLifecycleState.resumed:
        monitor.resumeFromBackground(DateTime.now());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // No-op — `inactive` fires on every system-level interruption
        // (incoming call, control center). `detached` fires only on
        // shutdown, where any monitor state is moot.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // v1.9.8 — P1 fix. Listen for the explicit "inactivity logout" signal
    // from `AuthNotifier._handleInactivityTimeout`. Using a dedicated
    // counter (not the auth state transition) avoids the ambiguity
    // between a deliberate logout from the profile screen and a forced
    // one from the inactivity monitor — both flip `Authenticated` →
    // `Unauthenticated`. The post-frame callback defers the SnackBar
    // until the router has had a chance to mount the login screen so
    // the message attaches to a live Scaffold.
    ref.listen<int>(inactivityLogoutSignalProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada por inactividad'),
            duration: Duration(seconds: 4),
          ),
        );
      });
    });

    return Listener(
      // `translucent` so the gesture wrapper poke fires on every pointer
      // event without consuming it — child widgets still receive their
      // gestures normally.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pokeInactivity,
      onPointerMove: _pokeInactivity,
      child: MaterialApp.router(
        title: 'AgriTrace',
        theme: buildAppTheme(),
        scaffoldMessengerKey: _messengerKey,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        // Mount PilotCountdownBanner above every screen. The widget
        // returns SizedBox.shrink() when not applicable (unauthenticated,
        // demo/admin, > 5 days remaining).
        builder: (context, child) => Column(
          children: [
            const PilotCountdownBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  void _pokeInactivity(PointerEvent _) {
    final monitor = ref.read(inactivityMonitorProvider);
    // `poke` is a no-op when the monitor is not running (unauthenticated
    // screens); calling `isRunning` keeps the hot path branch-light.
    if (monitor.isRunning) {
      monitor.poke();
    }
  }
}
