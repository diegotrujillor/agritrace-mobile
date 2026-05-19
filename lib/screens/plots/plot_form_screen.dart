import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/plot.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../utils/validators.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';

/// Create a plot under [farmId]. Area is optional for plots (a farmer may
/// register a lot before measuring it).
class PlotFormScreen extends ConsumerStatefulWidget {
  const PlotFormScreen({super.key, required this.farmId});

  final String farmId;

  @override
  ConsumerState<PlotFormScreen> createState() => _PlotFormScreenState();
}

class _PlotFormScreenState extends ConsumerState<PlotFormScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _varietyController = TextEditingController();
  final _areaController    = TextEditingController();

  String _cropType = kCropTypes.first;
  PlotStatus _status = PlotStatus.planning;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _varietyController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  String? _optionalArea(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return validateArea(value);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final areaText = _areaController.text.trim();
    final variety = _varietyController.text.trim();

    try {
      await ref.read(plotsProvider(widget.farmId).notifier).create(
            name: _nameController.text.trim(),
            cropType: _cropType,
            status: _status,
            variety: variety.isEmpty ? null : variety,
            areaHectares: areaText.isEmpty
                ? null
                : double.parse(areaText.replaceAll(',', '.')),
          );
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = parseAuthError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          'Agregar lote',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppInput(
                  label: 'Nombre del lote',
                  hint: 'Lote A',
                  controller: _nameController,
                  validator: validateRequiredText,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                _LabeledDropdown<String>(
                  label: 'Tipo de cultivo',
                  value: _cropType,
                  items: [
                    for (final crop in kCropTypes)
                      DropdownMenuItem(value: crop, child: Text(crop)),
                  ],
                  onChanged: (v) => setState(() => _cropType = v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Variedad (opcional)',
                  hint: 'CCN-51',
                  controller: _varietyController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Área (hectáreas, opcional)',
                  hint: '2.5',
                  controller: _areaController,
                  validator: _optionalArea,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.md),
                _LabeledDropdown<PlotStatus>(
                  label: 'Estado',
                  value: _status,
                  items: [
                    for (final s in PlotStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppErrorBanner(message: _errorMessage),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Agregar lote',
                  onPressed: _submitting ? null : _submit,
                  isLoading: _submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
