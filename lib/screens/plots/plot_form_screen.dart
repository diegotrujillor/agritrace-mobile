import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/route_names.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import 'widgets/plot_form.dart';

/// Create a plot under [farmId]. Area is optional for plots (a farmer may
/// register a lot before measuring it). Delegates the UI to the shared
/// [PlotForm] widget so create + edit screens stay in sync.
///
/// **v1.9.0:** when arrived at via the "auto-navigate after creating a
/// finca" flow, the parent route hands us a [initialCropTypeSuggestion]
/// (the free-text crop the producer typed on the farm form). We try to
/// match it to a plot-enum value with `matchPlotCropType` — if it does
/// (e.g. `'Cacao'` → `'cacao'`) the dropdown opens pre-selected. If it
/// doesn't, the form falls back to the default.
///
/// The AppBar back arrow always returns to the Dashboard (`/dashboard`)
/// because the farm form already replaced itself in the GoRouter stack
/// via `context.go`. Popping the empty stack would surface a `GoError`.
class PlotFormScreen extends ConsumerStatefulWidget {
  const PlotFormScreen({
    super.key,
    required this.farmId,
    this.initialCropTypeSuggestion,
  });

  final String farmId;
  final String? initialCropTypeSuggestion;

  @override
  ConsumerState<PlotFormScreen> createState() => _PlotFormScreenState();
}

class _PlotFormScreenState extends ConsumerState<PlotFormScreen> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit(PlotFormValues values) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(plotsProvider(widget.farmId).notifier).create(
            name: values.name,
            cropType: values.cropType,
            status: values.status,
            variety: values.variety,
            areaHectares: values.areaHectares,
          );
      if (!mounted) return;
      // After a successful create from the post-finca auto-nav flow the
      // stack is just [PlotFormScreen]. Going to the farm detail gives
      // the producer immediate confirmation that both the finca AND the
      // primer lote landed. From there the system back-button reaches
      // Dashboard one tap up. `go` (not `push`) so the form is removed.
      context.go(Routes.farmDetail(widget.farmId));
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
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Agregar lote'),
        // Explicit back leading: the previous route is gone (we arrived
        // via `context.go` from the farm form), so the default back arrow
        // would crash with a GoError on tap. Send the user straight to
        // Dashboard instead.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(Routes.dashboard),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PlotForm(
            submitLabel: 'Agregar lote',
            onSubmit: _submit,
            submitting: _submitting,
            errorMessage: _errorMessage,
            initialCropType:
                matchPlotCropType(widget.initialCropTypeSuggestion),
          ),
        ),
      ),
    );
  }
}

