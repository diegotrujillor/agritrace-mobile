import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/alert.dart';
import '../../navigation/route_names.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/farms_provider.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/offline_indicator.dart';
import '../../widgets/common/sync_status_badge.dart';
import '../../widgets/domain/alert_list_item.dart';

/// Producer-wide list of alerts (weather notices + scheduled reminders).
/// Surfaces the offline + sync status, supports dismiss/delete, and routes
/// to the reminder form via the FAB.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Alert alert,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar alerta'),
        content: Text('¿Eliminar "${alert.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(alertsProvider.notifier).deleteAlert(alert.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go(Routes.dashboard),
        ),
        title: const Text('Alertas'),
        actions: const [_WeatherCheckButton()],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          const SyncStatusBadge(),
          Expanded(
            child: alertsAsync.when(
              data: (alerts) => alerts.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none_outlined,
                      title: 'Sin alertas',
                      subtitle:
                          'Crea un recordatorio para tus tareas de cultivo',
                      subtitleHeight: 1.5,
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(alertsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return AlertListItem(
                            alert: alert,
                            onDismiss: alert.status == AlertStatus.dismissed
                                ? null
                                : () => ref
                                    .read(alertsProvider.notifier)
                                    .dismiss(alert.id),
                            onDelete: () => _confirmDelete(context, ref, alert),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: parseApiError(e),
                onRetry: () => ref.invalidate(alertsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        // push so the alert form can `context.pop()` back to this list.
        onPressed: () => context.push(Routes.alertNew),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text(
          'Recordatorio',
          style: GoogleFonts.inter(color: AppColors.white),
        ),
      ),
    );
  }
}

/// AppBar action that triggers a manual weather check across every plot the
/// producer owns. Walks the user's farms → their plots, calls
/// `POST /v1/alerts/weather/check` per plot, and surfaces the aggregated
/// result via a snackbar. CU-19.
///
/// Stateful so the icon can swap to a `CircularProgressIndicator` while the
/// request is in flight — keeps the rest of [AlertsScreen] as a plain
/// `ConsumerWidget`.
class _WeatherCheckButton extends ConsumerStatefulWidget {
  const _WeatherCheckButton();

  @override
  ConsumerState<_WeatherCheckButton> createState() =>
      _WeatherCheckButtonState();
}

class _WeatherCheckButtonState extends ConsumerState<_WeatherCheckButton> {
  bool _inFlight = false;

  Future<void> _onPressed() async {
    if (_inFlight) return;
    // Capture messenger BEFORE awaits to dodge use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _inFlight = true);
    try {
      // Collect every plot id from every farm the producer owns. The weather
      // endpoint is per-plot, so the screen aggregates client-side rather
      // than introducing a new "user-wide" backend route.
      final farms = await ref.read(farmServiceProvider).list();
      final plotIds = <String>[];
      for (final farm in farms) {
        final plots = await ref.read(plotServiceProvider).listByFarm(farm.id);
        plotIds.addAll(plots.map((p) => p.id));
      }
      final newAlerts = await ref
          .read(alertsProvider.notifier)
          .runWeatherCheckForAllPlots(plotIds);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newAlerts > 0
                ? 'Clima actualizado · $newAlerts ${newAlerts == 1 ? "alerta nueva" : "alertas nuevas"}'
                : 'Clima actualizado',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('No se pudo chequear el clima. Intenta más tarde.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inFlight) {
      // Match the IconButton 48dp touch target so the AppBar height does not
      // jump while the request is in flight.
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.white),
            ),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Actualizar clima',
      icon: const Icon(Icons.cloud_sync, color: AppColors.white),
      onPressed: _onPressed,
    );
  }
}
