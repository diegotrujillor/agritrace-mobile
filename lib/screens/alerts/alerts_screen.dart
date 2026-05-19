import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/alert.dart';
import '../../navigation/route_names.dart';
import '../../providers/alerts_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
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
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go(Routes.dashboard),
        ),
        title: Text(
          'Alertas',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          const SyncStatusBadge(),
          Expanded(
            child: alertsAsync.when(
              data: (alerts) => alerts.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.refresh(alertsProvider.future),
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
                            onDelete: () =>
                                _confirmDelete(context, ref, alert),
                          );
                        },
                      ),
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: parseAuthError(e),
                onRetry: () => ref.invalidate(alertsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => context.go(Routes.alertNew),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: Text(
          'Recordatorio',
          style: GoogleFonts.inter(color: AppColors.white),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_outlined,
              size: 80,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sin alertas',
              style: GoogleFonts.inter(
                color: AppColors.darkGreen,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Crea un recordatorio para tus tareas de cultivo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
