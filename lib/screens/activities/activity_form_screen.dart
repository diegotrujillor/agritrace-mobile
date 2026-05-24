import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_logo_mark.dart';
import 'widgets/activity_form.dart';

/// Register an activity for [plotId]. Type + occurred-on date are required;
/// description and a photo URL are optional. Photo upload is a stub this
/// sprint (a plain URL field) — file capture is a later release.
///
/// Delegates the form rendering + local state to the shared [ActivityForm]
/// widget so create + edit (see [ActivityEditScreen]) stay DRY.
class ActivityFormScreen extends ConsumerWidget {
  const ActivityFormScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Registrar actividad'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                // v1.9.3 — QA cycle-03: reserve grew 56 → 80 px to clear
                // the bumped brand mark below.
                AppSpacing.xl + 80,
              ),
              child: ActivityForm(
                submitLabel: 'Registrar actividad',
                onSubmit: ({
                  required ActivityType type,
                  required DateTime occurredAt,
                  String? description,
                  String? photoUrl,
                }) async {
                  // Capture router before await to avoid
                  // use_build_context_synchronously across the network call.
                  final router = GoRouter.of(context);
                  await ref
                      .read(activitiesProvider(plotId).notifier)
                      .createActivity(
                        type: type,
                        occurredAt: occurredAt,
                        description: description,
                        photoUrl: photoUrl,
                      );
                  router.pop();
                },
              ),
            ),
            // v1.9.3 — QA cycle-03: bump brand mark 2× (40 → 80 px).
            // Alignment + position unchanged (bottom-left).
            const Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: AppLogoMark(size: 80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
