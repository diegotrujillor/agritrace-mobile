import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/activity.dart';
import '../../providers/activities_provider.dart';
import '../../utils/constants.dart';
import '../../utils/date_format.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_date_field.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/app_labeled_dropdown.dart';

/// Register an activity for [plotId]. Type + occurred-on date are required;
/// description and a photo URL are optional. Photo upload is a stub this
/// sprint (a plain URL field) — file capture is a later release.
class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({super.key, required this.plotId});

  final String plotId;

  @override
  ConsumerState<ActivityFormScreen> createState() =>
      _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _photoUrlController = TextEditingController();

  ActivityType _type = ActivityType.sowing;
  DateTime _occurredAt = DateTime.now();
  bool _submitting = false;
  String? _errorMessage;

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
      await ref.read(activitiesProvider(widget.plotId).notifier).createActivity(
            type: _type,
            occurredAt: _occurredAt,
            description: description.isEmpty ? null : description,
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
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
        title: const Text('Registrar actividad'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
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
                  label: 'Registrar actividad',
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

