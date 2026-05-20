import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import 'widgets/activity_form.dart';

/// Edit an existing activity identified by [activityId].
///
/// Loads the activity through [activityProvider] and renders the shared
/// [ActivityForm] pre-filled with the current values. Submitting calls
/// `activitiesProvider(plotId).notifier.updateActivity(...)`, shows a
/// success snackbar and pops back to the timeline.
class ActivityEditScreen extends ConsumerWidget {
  const ActivityEditScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(activityProvider(activityId));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Editar actividad'),
      ),
      body: SafeArea(
        child: activityAsync.when(
          data: (activity) => _EditBody(activity: activity),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                parseApiError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inner body that wires the prefilled [ActivityForm] to the update provider.
///
/// `messenger` + `router` are captured before the await so the
/// `use_build_context_synchronously` lint stays satisfied across the call.
class _EditBody extends ConsumerWidget {
  const _EditBody({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ActivityForm(
        submitLabel: 'Guardar cambios',
        initialType: activity.type,
        initialOccurredAt: activity.occurredAt,
        initialDescription: activity.description,
        initialPhotoUrl: activity.photoUrl,
        onSubmit: ({
          required ActivityType type,
          required DateTime occurredAt,
          String? description,
          String? photoUrl,
        }) async {
          // Capture before await to avoid use_build_context_synchronously.
          final messenger = ScaffoldMessenger.of(context);
          final router = GoRouter.of(context);

          await ref
              .read(activitiesProvider(activity.plotId).notifier)
              .updateActivity(
                id: activity.id,
                type: type,
                occurredAt: occurredAt,
                description: description,
                photoUrl: photoUrl,
              );
          // Invalidate the single-activity lookup so a future open of the
          // edit screen reflects the freshly persisted values.
          ref.invalidate(activityProvider(activity.id));
          messenger.showSnackBar(
            const SnackBar(content: Text('Actividad actualizada')),
          );
          router.pop();
        },
      ),
    );
  }
}
