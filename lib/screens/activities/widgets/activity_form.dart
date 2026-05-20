import 'package:flutter/material.dart';
import '../../../models/activity.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_format.dart';
import '../../../utils/error_parser.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_date_field.dart';
import '../../../widgets/common/app_error_banner.dart';
import '../../../widgets/common/app_input.dart';
import '../../../widgets/common/app_labeled_dropdown.dart';

/// Shared form body for creating and editing an activity. Renders the 4
/// fields (type / occurred-on date / optional note / optional photo URL),
/// owns the local form state and delegates persistence to [onSubmit].
///
/// [onSubmit] is `async` so the form can show the spinner while the parent
/// performs the network call (create or update) and pop on success. If the
/// callback throws, the form re-enables the button and surfaces the
/// parsed error in the embedded banner.
class ActivityForm extends StatefulWidget {
  const ActivityForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initialType = ActivityType.sowing,
    this.initialOccurredAt,
    this.initialDescription,
    this.initialPhotoUrl,
  });

  /// CTA label (e.g. "Registrar actividad" or "Guardar cambios").
  final String submitLabel;

  /// Called with the validated form payload. Should throw on failure so the
  /// form can render the error banner; resolve normally on success — the
  /// parent owns navigation (`context.pop()`) and any success snackbar.
  final Future<void> Function({
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) onSubmit;

  final ActivityType initialType;
  final DateTime? initialOccurredAt;
  final String? initialDescription;
  final String? initialPhotoUrl;

  @override
  State<ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<ActivityForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _photoUrlController;

  late ActivityType _type;
  late DateTime _occurredAt;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _occurredAt = widget.initialOccurredAt ?? DateTime.now();
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _photoUrlController =
        TextEditingController(text: widget.initialPhotoUrl ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _occurredAt = picked);
    }
  }

  String? _optionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Ingresa una URL válida';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();
    final photoUrl = _photoUrlController.text.trim();

    try {
      await widget.onSubmit(
        type: _type,
        occurredAt: _occurredAt,
        description: description.isEmpty ? null : description,
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
      );
      // On success the parent typically pops this route; clearing the
      // submitting flag here would race with a possibly-unmounted state.
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLabeledDropdown<ActivityType>(
            label: 'Tipo de actividad',
            value: _type,
            items: [
              for (final t in ActivityType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppDateField(
            label: 'Fecha de la actividad',
            value: formatLocalDate(_occurredAt),
            onTap: _pickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Nota (opcional)',
            hint: 'Detalle de la actividad',
            controller: _descriptionController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'URL de foto (opcional)',
            hint: 'https://...',
            controller: _photoUrlController,
            validator: _optionalUrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppErrorBanner(message: _errorMessage),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.submitLabel,
            onPressed: _submitting ? null : _submit,
            isLoading: _submitting,
          ),
        ],
      ),
    );
  }
}
