import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../navigation/route_names.dart';
import '../../providers/activities_provider.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/domain/activity_list_item.dart';

/// Full-screen chronological timeline of a plot's activities (newest first).
/// "Registrar actividad" routes to the activity form; long-pressing any
/// activity row opens a contextual bottom sheet with Editar / Eliminar
/// (CU-16 + CU-17).
class ActivityTimelineScreen extends ConsumerWidget {
  const ActivityTimelineScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotAsync = ref.watch(plotProvider(plotId));
    final activitiesAsync = ref.watch(activitiesProvider(plotId));

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        title: Text(plotAsync.valueOrNull?.name ?? 'Actividades'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(activitiesProvider(plotId).future),
        child: activitiesAsync.when(
          data: (activities) {
            if (activities.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: AppSpacing.xl),
                  EmptyState(
                    subtitle:
                        'Este lote aún no tiene actividades registradas',
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                  ),
                ],
              );
            }
            // Sort once per data emission, not per itemBuilder call (the
            // builder runs on every frame while scrolling — sorting there
            // was O(n²)).
            final sorted = _sorted(activities);
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: sorted.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) => ActivityListItem(
                activity: sorted[index],
                onLongPress: () =>
                    _showActionsSheet(context, ref, sorted[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    parseApiError(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        // push so the activity form can `context.pop()` back to the timeline.
        onPressed: () => context.push(Routes.activityNew(plotId)),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Registrar actividad',
          style: TextStyle(color: AppColors.white),
        ),
      ),
    );
  }

  /// Opens the contextual "Editar / Eliminar" bottom sheet for [activity].
  ///
  /// Closing the sheet and the subsequent navigation/dialog use the
  /// captured root `context` so the gestures survive once the sheet route
  /// is popped.
  Future<void> _showActionsSheet(
    BuildContext context,
    WidgetRef ref,
    Activity activity,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(Routes.activityEdit(activity.id));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref, activity);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the destructive confirmation dialog and, on confirm, deletes the
  /// activity through the provider. `messenger` is captured before the
  /// await so the lint `use_build_context_synchronously` stays satisfied
  /// across the network call.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Activity activity,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta actividad?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(activitiesProvider(plotId).notifier)
          .deleteActivity(activity.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Actividad eliminada')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    }
  }
}

/// Newest first. Copies the list before sorting so the provider's immutable
/// state is never mutated in place.
List<Activity> _sorted(List<Activity> activities) {
  final copy = [...activities];
  copy.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return copy;
}

