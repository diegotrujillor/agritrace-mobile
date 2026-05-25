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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // v1.9.4 — QA hotfix: centered brand mark below the
              // AppBar, mirroring the header-logo pattern added to
              // every form screen in this release.
              // v1.9.5 — duplicate bottom-left logo removed; this is
              // now the only AppLogoMark on the screen.
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: AppLogoMark(size: 80),
                ),
              ),
              ActivityForm(
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
            ],
          ),
        ),
      ),
    );
  }
}
