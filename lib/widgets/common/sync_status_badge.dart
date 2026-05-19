import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sync_provider.dart';
import '../../utils/constants.dart';

/// Compact, tappable sync-status surface.
///
/// Reflects [syncProvider]: idle (never synced this session), syncing,
/// last result (synced / conflicts) or error. Tapping triggers a push+pull
/// round trip via `SyncNotifier.trigger`. With no local change journal yet
/// (later release) the push leg sends an empty change set; the value here
/// is surfacing sync state to the farmer.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);

    final (IconData icon, String label, Color color) = sync.when(
      loading: () =>
          (Icons.sync, 'Sincronizando…', AppColors.grey),
      error: (_, __) =>
          (Icons.sync_problem, 'Error al sincronizar', AppColors.error),
      data: (result) {
        if (result == null) {
          return (Icons.sync, 'Tocar para sincronizar', AppColors.grey);
        }
        if (result.conflicts > 0) {
          return (
            Icons.sync_problem,
            '${result.synced} sincronizados · ${result.conflicts} conflictos',
            AppColors.harvestYellow,
          );
        }
        return (
          Icons.cloud_done_outlined,
          'Sincronizado (${result.synced})',
          AppColors.primaryGreen,
        );
      },
    );

    final isSyncing = sync.isLoading;

    return InkWell(
      onTap: isSyncing
          ? null
          : () => ref.read(syncProvider.notifier).trigger(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: AppSpacing.md,
        ),
        color: color.withValues(alpha: 0.12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
