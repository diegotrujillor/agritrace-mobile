import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pilot_status_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_logo_mark.dart';

/// Full-screen block shown when the producer's pilot window is not active.
///
/// Two states:
///   - [PilotStatusCode.notStarted]: signed agreement not yet recorded by
///     the operator via `POST /v1/internal/pilots/start`.
///   - [PilotStatusCode.expired]: the 30-day window has elapsed.
///
/// Data-export and logout remain accessible (Ley 1581 clean-exit right).
/// Reached via the GoRouter redirect in `app_router.dart`.
class PilotBlockedScreen extends ConsumerWidget {
  const PilotBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pilotStatusProvider);
    final isExpired = status.code == PilotStatusCode.expired;

    final title = isExpired ? 'Piloto finalizado' : 'Acceso pendiente';
    final message = isExpired
        ? 'Tu período de piloto de 30 días ha terminado.\n\n'
            'Tus datos están seguros. Para continuar usando AgriTrace '
            'o exportar tu información, contacta al equipo.'
        : 'Tu cuenta ha sido creada pero el acceso al piloto '
            'aún no ha sido activado por el equipo AgriTrace.\n\n'
            'Recibirás confirmación una vez que tu acuerdo esté registrado.';

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              const AppLogoMark(size: 80),
              const SizedBox(height: AppSpacing.xl),
              Icon(
                isExpired ? Icons.lock_clock : Icons.hourglass_empty,
                size: 64,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkGreen,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Ley 1581: producers must always be able to request their data
              // even after a pilot expires.
              if (isExpired)
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.profile),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar mis datos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.earthBrown,
                  side: const BorderSide(color: AppColors.earthBrown),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'AgriTrace · diegotrujillor@gmail.com',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
