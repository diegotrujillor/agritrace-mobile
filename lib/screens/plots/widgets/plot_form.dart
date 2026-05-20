import 'package:flutter/material.dart';
import '../../../models/plot.dart';
import '../../../utils/constants.dart';
import '../../../utils/validators.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_error_banner.dart';
import '../../../widgets/common/app_input.dart';
import '../../../widgets/common/app_labeled_dropdown.dart';

/// Immutable payload emitted by [PlotForm.onSubmit] when the form validates.
///
/// Holds the four user-controlled fields a plot can carry; the calling screen
/// decides whether to invoke `create` or `update` on the provider with it.
class PlotFormValues {
  const PlotFormValues({
    required this.name,
    required this.cropType,
    required this.status,
    this.variety,
    this.areaHectares,
  });

  final String name;
  final String cropType;
  final PlotStatus status;
  final String? variety;
  final double? areaHectares;
}

/// Shared form for creating and editing a [Plot]. Owns its own controllers and
/// `Form` key so callers only have to wire submit + state.
///
/// When [initial] is provided the fields are pre-filled (edit mode). The
/// [submitLabel] is shown on the submit button (e.g. "Agregar lote" /
/// "Guardar cambios"). [submitting] disables the button + shows the spinner,
/// and [errorMessage] (nullable) renders an [AppErrorBanner] above it.
class PlotForm extends StatefulWidget {
  const PlotForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.submitting = false,
    this.errorMessage,
  });

  final String submitLabel;
  final ValueChanged<PlotFormValues> onSubmit;
  final Plot? initial;
  final bool submitting;
  final String? errorMessage;

  @override
  State<PlotForm> createState() => _PlotFormState();
}

class _PlotFormState extends State<PlotForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _varietyController = TextEditingController();
  final _areaController = TextEditingController();

  late String _cropType;
  late PlotStatus _status;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _cropType = (initial != null && kCropTypes.contains(initial.cropType))
        ? initial.cropType
        : kCropTypes.first;
    _status = initial?.status ?? PlotStatus.planning;
    if (initial != null) {
      _nameController.text = initial.name;
      _varietyController.text = initial.variety ?? '';
      if (initial.areaHectares != null) {
        _areaController.text = initial.areaHectares.toString();
      }
    }
  }

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

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final variety = _varietyController.text.trim();
    final areaText = _areaController.text.trim();
    widget.onSubmit(
      PlotFormValues(
        name: _nameController.text.trim(),
        cropType: _cropType,
        status: _status,
        variety: variety.isEmpty ? null : variety,
        areaHectares: areaText.isEmpty
            ? null
            : double.parse(areaText.replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
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
          AppLabeledDropdown<String>(
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
            onFieldSubmitted: (_) => _handleSubmit(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppLabeledDropdown<PlotStatus>(
            label: 'Estado',
            value: _status,
            items: [
              for (final s in PlotStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => setState(() => _status = v),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppErrorBanner(message: widget.errorMessage),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.submitLabel,
            onPressed: widget.submitting ? null : _handleSubmit,
            isLoading: widget.submitting,
          ),
        ],
      ),
    );
  }
}
