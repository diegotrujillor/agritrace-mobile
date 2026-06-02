import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pilot_status_provider.dart';
import '../../utils/constants.dart';

/// Days remaining below which the amber countdown strip appears.
const int kPilotCountdownThresholdDays = 5;

/// App-wide amber banner shown when the 30-day pilot window is ≤5 days
/// from closing.
///
/// Mounted via [MaterialApp.router.builder] in `main.dart` so it appears
/// above every authenticated screen. Returns [SizedBox.shrink] when:
///   - user is unauthenticated, demo, or admin (exempt)
///   - pilot is active with > [kPilotCountdownThresholdDays] days left
///   - pilot is not-started or expired (router handles redirect instead)
class PilotCountdownBanner extends ConsumerWidget {
  const PilotCountdownBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pilotStatusProvider);
    final days = status.daysRemaining;

    if (status.code != PilotStatusCode.active ||
        days == null ||
        days > kPilotCountdownThresholdDays) {
      return const SizedBox.shrink();
    }

    final label = days == 0
        ? 'Tu piloto vence hoy — exporta tus datos desde Perfil'
        : 'Tu piloto vence en $days ${days == 1 ? "día" : "días"}'
            ' — contacta al equipo AgriTrace';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: AppColors.harvestYellow,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
