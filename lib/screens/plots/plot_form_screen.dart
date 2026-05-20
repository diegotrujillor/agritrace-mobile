import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import 'widgets/plot_form.dart';

/// Create a plot under [farmId]. Area is optional for plots (a farmer may
/// register a lot before measuring it). Delegates the UI to the shared
/// [PlotForm] widget so create + edit screens stay in sync.
class PlotFormScreen extends ConsumerStatefulWidget {
  const PlotFormScreen({super.key, required this.farmId});

  final String farmId;

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
      context.pop();
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PlotForm(
            submitLabel: 'Agregar lote',
            onSubmit: _submit,
            submitting: _submitting,
            errorMessage: _errorMessage,
          ),
        ),
      ),
    );
  }
}

