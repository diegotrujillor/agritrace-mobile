import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navigation/app_router.dart';
import 'utils/theme.dart';

void main() {
  // Block google_fonts from making outbound HTTP requests to fonts.gstatic.com.
  // Ley 1581: don't leak farmer IPs to Google CDN. Offline-first rural
  // environment cannot rely on a CDN anyway — fonts must be bundled.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: AgriTraceApp()));
}

class AgriTraceApp extends ConsumerWidget {
  const AgriTraceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'AgriTrace',
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
