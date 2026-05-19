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
                data: (activities) => activities.isEmpty
                    ? const _NoActivities()
                    : Column(
                        children: [
                          for (final activity in _sorted(activities)) ...[
                            ActivityListItem(activity: activity),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => context.go(Routes.activityNew(plotId)),
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
        SnackBar(content: Text(parseAuthError(error))),
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

class _NoActivities extends StatelessWidget {
  const _NoActivities();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          'Este lote aún no tiene actividades registradas',
          textAlign: TextAlign.center,
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
