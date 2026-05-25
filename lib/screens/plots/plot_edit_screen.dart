import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/plot.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_logo_mark.dart';
import 'widgets/plot_form.dart';

/// Edit an existing plot identified by [plotId].
///
/// Loads the plot through [plotProvider] and renders the shared [PlotForm]
/// pre-filled with the current values. Submitting calls
/// `plotsProvider(farmId).notifier.updatePlot(...)` and pops on success.
class PlotEditScreen extends ConsumerWidget {
  const PlotEditScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotAsync = ref.watch(plotProvider(plotId));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Editar lote'),
      ),
      body: SafeArea(
        child: plotAsync.when(
          data: (plot) => _EditBody(plot: plot),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                parseApiError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inner stateful body that owns submit/error state once the plot is loaded.
class _EditBody extends ConsumerStatefulWidget {
  const _EditBody({required this.plot});

  final Plot plot;

  @override
  ConsumerState<_EditBody> createState() => _EditBodyState();
}

class _EditBodyState extends ConsumerState<_EditBody> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit(PlotFormValues values) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    // Capture before await to avoid use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await ref
          .read(plotsProvider(widget.plot.farmId).notifier)
          .updatePlot(
            id: widget.plot.id,
            name: values.name,
            cropType: values.cropType,
            status: values.status,
            variety: values.variety,
            areaHectares: values.areaHectares,
          );
      // v1.9.0 — bug #28 fix. Invalidate BOTH the single-plot lookup
      // (so the detail header re-reads from the local DB after the
      // update) AND the family-scoped list (in case the Drift reactive
      // stream emits before the notifier's write completes and the
      // detail screen is rebuilt against a stale snapshot).
      ref.invalidate(plotProvider(widget.plot.id));
      ref.invalidate(plotsProvider(widget.plot.farmId));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Lote actualizado')),
      );
      router.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = parseApiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // v1.9.4 — QA hotfix: brand mark was missing from this screen
          // entirely (Pantalla 18 in the v1.9.3 user-feedback captures).
          // Place a centered 80 px mark directly under the AppBar, before
          // the first form field, mirroring the size used on the other
          // form screens. `vertical: 16` keeps it from crashing into the
          // field row that follows.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: AppLogoMark(size: 80),
            ),
          ),
          PlotForm(
            submitLabel: 'Guardar cambios',
            onSubmit: _submit,
            initial: widget.plot,
            submitting: _submitting,
            errorMessage: _errorMessage,
          ),
        ],
      ),
    );
  }
}
