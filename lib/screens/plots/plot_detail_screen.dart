import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/plot.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_card.dart';

/// Plot summary. The activity timeline is Sprint 3 — shown here as a labelled
/// placeholder section so the navigation target exists now.
class PlotDetailScreen extends ConsumerWidget {
  const PlotDetailScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotAsync = ref.watch(plotProvider(plotId));

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          plotAsync.valueOrNull?.name ?? 'Lote',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: plotAsync.when(
        data: (plot) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _PlotSummary(plot: plot),
            const SizedBox(height: AppSpacing.lg),
            const _ActivityPlaceholder(),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              parseAuthError(e),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlotSummary extends StatelessWidget {
  const _PlotSummary({required this.plot});

  final Plot plot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plot.name,
            style: GoogleFonts.inter(
              color: AppColors.darkGreen,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: 'Cultivo', value: plot.cropType),
          if (plot.variety != null && plot.variety!.isNotEmpty)
            _InfoRow(label: 'Variedad', value: plot.variety!),
          if (plot.areaHectares != null)
            _InfoRow(label: 'Área', value: '${plot.areaHectares} ha'),
          _InfoRow(label: 'Estado', value: plot.status.label),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkGreen,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividades',
            style: GoogleFonts.inter(
              color: AppColors.darkGreen,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'La línea de tiempo de actividades estará disponible en una '
            'próxima versión.',
            style: TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
