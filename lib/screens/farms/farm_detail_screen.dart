import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/farm.dart';
import '../../models/plot.dart';
import '../../navigation/route_names.dart';
import '../../providers/farms_provider.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_card.dart';

/// Farm header + its plots list. "Agregar lote" routes to the plot form.
class FarmDetailScreen extends ConsumerWidget {
  const FarmDetailScreen({super.key, required this.farmId});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmAsync = ref.watch(farmProvider(farmId));
    final plotsAsync = ref.watch(plotsProvider(farmId));

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          farmAsync.valueOrNull?.name ?? 'Finca',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (farmAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.white),
              tooltip: 'Editar finca',
              onPressed: () => context.go(
                Routes.farmsNew,
                extra: farmAsync.value,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(plotsProvider(farmId).future),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            farmAsync.when(
              data: (farm) => _FarmHeader(farm: farm),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _InlineError(message: parseAuthError(e)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Lotes',
              style: GoogleFonts.inter(
                color: AppColors.darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            plotsAsync.when(
              data: (plots) => plots.isEmpty
                  ? const _NoPlots()
                  : Column(
                      children: [
                        for (final plot in plots) ...[
                          _PlotTile(plot: plot),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _InlineError(message: parseAuthError(e)),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => context.go(Routes.plotNew(farmId)),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Agregar lote',
          style: TextStyle(color: AppColors.white),
        ),
      ),
    );
  }
}

class _FarmHeader extends StatelessWidget {
  const _FarmHeader({required this.farm});

  final Farm farm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            farm.name,
            style: GoogleFonts.inter(
              color: AppColors.darkGreen,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: 'Cultivo', value: farm.cropType),
          _InfoRow(
            label: 'Área',
            value: '${farm.areaHectares} ha',
          ),
          if (farm.address != null && farm.address!.isNotEmpty)
            _InfoRow(label: 'Dirección', value: farm.address!),
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
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 14,
              ),
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

class _PlotTile extends StatelessWidget {
  const _PlotTile({required this.plot});

  final Plot plot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(Routes.plotDetail(plot.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plot.name,
                  style: GoogleFonts.inter(
                    color: AppColors.darkGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${plot.cropType} · ${plot.status.label}',
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.grey),
        ],
      ),
    );
  }
}

class _NoPlots extends StatelessWidget {
  const _NoPlots();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          'Esta finca aún no tiene lotes',
          style: TextStyle(color: AppColors.grey, fontSize: 16),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error, fontSize: 16),
        ),
      ),
    );
  }
}
