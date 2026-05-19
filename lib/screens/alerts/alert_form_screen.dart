import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/alerts_provider.dart';
import '../../utils/constants.dart';
import '../../utils/date_format.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_date_field.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';

/// Create a scheduled reminder (an `AlertType.reminder`). Title and the
/// scheduled date are required; the note is optional. Weather alerts are
/// raised server-side via the weather check, not from this form.
class AlertFormScreen extends ConsumerStatefulWidget {
  const AlertFormScreen({super.key});

  @override
  ConsumerState<AlertFormScreen> createState() => _AlertFormScreenState();
}

class _AlertFormScreenState extends ConsumerState<AlertFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  DateTime _scheduledFor = DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledFor,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _scheduledFor = picked);
    }
  }

  String? _requiredTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El título es obligatorio';
    }
    if (value.trim().length > 160) {
      return 'Máximo 160 caracteres';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final body = _bodyController.text.trim();
    try {
      await ref.read(alertsProvider.notifier).createReminder(
            title: _titleController.text.trim(),
            scheduledFor: _scheduledFor,
            body: body.isEmpty ? null : body,
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
        title: const Text('Nuevo recordatorio'),
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
                  label: 'Título',
                  hint: 'Ej: Fertilizar lote norte',
                  controller: _titleController,
                  validator: _requiredTitle,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppDateField(
                  label: 'Fecha del recordatorio',
                  value: formatLocalDate(_scheduledFor),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Nota (opcional)',
                  hint: 'Detalle de la tarea',
                  controller: _bodyController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppErrorBanner(message: _errorMessage),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Crear recordatorio',
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

