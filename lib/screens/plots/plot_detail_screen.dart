import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/activity.dart';
import '../../models/plot.dart';
import '../../navigation/route_names.dart';
import '../../providers/activities_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/farms_provider.dart';
import '../../providers/plots_provider.dart';
import '../../services/pdf_traceability_service.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/info_row.dart';
import '../../widgets/common/inline_error.dart';
import '../../widgets/domain/activity_list_item.dart';

/// Plot summary + its activity timeline. Offers registering a new activity
/// and exporting a client-side traceability PDF (Pantalla 9).
class PlotDetailScreen extends ConsumerWidget {
  const PlotDetailScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotAsync = ref.watch(plotProvider(plotId));
    final activitiesAsync = ref.watch(activitiesProvider(plotId));

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        title: Text(plotAsync.valueOrNull?.name ?? 'Lote'),
      ),
      body: plotAsync.when(
        data: (plot) => RefreshIndicator(
          onRefresh: () => ref.refresh(activitiesProvider(plotId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _PlotSummary(plot: plot),
              const SizedBox(height: AppSpacing.md),
              _ExportPdfButton(plot: plot),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Actividades',
                style: GoogleFonts.inter(
                  color: AppColors.darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              activitiesAsync.when(
                data: (activities) {
                  if (activities.isEmpty) {
                    return const EmptyState(
                      subtitle:
                          'Este lote aún no tiene actividades registradas',
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    );
                  }
                  // Sort once per data emission (mirrors the timeline
                  // screen's corrected pattern).
                  final sorted = _sorted(activities);
                  return Column(
                    children: [
                      for (final activity in sorted) ...[
                        ActivityListItem(activity: activity),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => InlineError(message: parseApiError(e)),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              parseApiError(e),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 16),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        // push so the activity form can `context.pop()` back to this detail.
        onPressed: () => context.push(Routes.activityNew(plotId)),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Registrar actividad',
          style: TextStyle(color: AppColors.white),
        ),
      ),
    );
  }
}

/// Newest first. Copies before sorting so the provider's immutable state is
/// never mutated in place.
List<Activity> _sorted(List<Activity> activities) {
  final copy = [...activities];
  copy.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return copy;
}

/// "Exportar PDF de trazabilidad". Pulls the parent farm + producer name and
/// generates the client-side PDF, then opens the share/print sheet. Disabled
/// while exporting so a double-tap cannot launch two share sheets.
class _ExportPdfButton extends ConsumerStatefulWidget {
  const _ExportPdfButton({required this.plot});

  final Plot plot;

  @override
  ConsumerState<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends ConsumerState<_ExportPdfButton> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final farm =
          await ref.read(farmProvider(widget.plot.farmId).future);
      final activities =
          await ref.read(activitiesProvider(widget.plot.id).future);
      final auth = ref.read(authProvider).valueOrNull;
      final producerName =
          auth is AuthAuthenticated ? auth.user.fullName : null;

      await const PdfTraceabilityService().buildAndShare(
        farm: farm,
        plot: widget.plot,
        activities: activities,
        producerName: producerName,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(parseApiError(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _export,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen, width: 2),
        minimumSize: const Size(double.infinity, 52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: const Text('Exportar PDF de trazabilidad'),
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
          InfoRow(label: 'Cultivo', value: plot.cropType),
          if (plot.variety != null && plot.variety!.isNotEmpty)
            InfoRow(label: 'Variedad', value: plot.variety!),
          if (plot.areaHectares != null)
            InfoRow(label: 'Área', value: '${plot.areaHectares} ha'),
          InfoRow(label: 'Estado', value: plot.status.label),
        ],
      ),
    );
  }
}

