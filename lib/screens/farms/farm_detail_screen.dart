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
import '../../widgets/common/app_logo_mark.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/info_row.dart';
import '../../widgets/common/inline_error.dart';

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
        // Explicit back leading: dashboard navigates here via `context.go`
        // (stack-replacing), so Material would not auto-inject a back arrow.
        // Mirrors the same pattern in `plot_form_screen.dart`.
        // PDF QA cycle-01 #11.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(Routes.dashboard),
        ),
        title: Text(farmAsync.valueOrNull?.name ?? 'Finca'),
        actions: [
          if (farmAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.white),
              tooltip: 'Editar finca',
              // push (not go) so the edit form can `context.pop()` back to
              // this detail screen; `go` replaces the stack and would surface
              // a silent GoError after a successful update.
              onPressed: () => context.push(
                Routes.farmsNew,
                extra: farmAsync.value,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
              error: (e, _) => InlineError(message: parseApiError(e)),
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
                  ? const EmptyState(
                      subtitle: 'Esta finca aún no tiene lotes',
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    )
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
              error: (e, _) => InlineError(message: parseApiError(e)),
            ),
              ],
            ),
          ),
          // v1.9.2 — QA cycle-01 #12: brand mark bottom-left at the same
          // height as the "Agregar lote" FAB on the opposite corner.
          const Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            child: AppLogoMark(size: 56),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        // push so the plot form can `context.pop()` back to this detail.
        onPressed: () => context.push(Routes.plotNew(farmId)),
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
          InfoRow(label: 'Cultivo', value: farm.cropType),
          InfoRow(
            label: 'Área',
            value: '${farm.areaHectares} ha',
          ),
          if (farm.address != null && farm.address!.isNotEmpty)
            InfoRow(label: 'Dirección', value: farm.address!),
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
                  // v1.9.2 — QA cycle-02: render the human label so saved
                  // lotes show "Caña panelera" instead of the raw wire
                  // value "cana_panelera". Submits still send the canonical
                  // snake_case value to the backend.
                  '${cropTypeLabel(plot.cropType)} · ${plot.status.label}',
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

