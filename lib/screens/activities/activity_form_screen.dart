import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';
import '../../utils/constants.dart';
import '../../utils/date_format.dart';
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

                  // v1.9.6 — soft duplicate warning. Only types in
                  // `kDuplicateWarnActivityTypes` trigger the prompt; this
                  // screen is create-only (edit lives in
                  // [ActivityEditScreen]), so the implicit "create" guard
                  // is already satisfied by being here. Hard-blocking is
                  // explicitly out of scope — the user can always answer
                  // "Sí, continuar" and persist anyway.
                  if (kDuplicateWarnActivityTypes.contains(type)) {
                    final duplicates = await ref
                        .read(activitiesProvider(plotId).notifier)
                        .findByPlotTypeAndDate(
                          type: type,
                          date: occurredAt,
                        );
                    if (duplicates.isNotEmpty) {
                      if (!context.mounted) return;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Ya registraste ${type.label}'),
                          content: Text(
                            'Ya hay un registro de ${type.label} para este '
                            'lote en la fecha ${formatLocalDate(occurredAt)}. '
                            '¿Continuar de todas formas?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sí, continuar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }
                  }

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
