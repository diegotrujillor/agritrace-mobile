import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/farm.dart';
import '../../providers/farms_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../utils/validators.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/app_labeled_dropdown.dart';

/// Create / edit a farm. When [farm] is null this is a create form; otherwise
/// the fields are pre-filled and submit issues a `PUT`.
class FarmFormScreen extends ConsumerStatefulWidget {
  const FarmFormScreen({super.key, this.farm});

  final Farm? farm;

  @override
  ConsumerState<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends ConsumerState<FarmFormScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _nameController    = TextEditingController();
  final _areaController    = TextEditingController();
  final _addressController = TextEditingController();

  late String _cropType;
  bool _submitting = false;
  String? _errorMessage;

  bool get _isEdit => widget.farm != null;

  @override
  void initState() {
    super.initState();
    final farm = widget.farm;
    _cropType = (farm != null && kCropTypes.contains(farm.cropType))
        ? farm.cropType
        : kCropTypes.first;
    if (farm != null) {
      _nameController.text = farm.name;
      _areaController.text = farm.areaHectares.toString();
      _addressController.text = farm.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final area =
        double.parse(_areaController.text.trim().replaceAll(',', '.'));
    final address = _addressController.text.trim();
    final notifier = ref.read(farmsProvider.notifier);

    try {
      if (_isEdit) {
        await notifier.updateFarm(
          id: widget.farm!.id,
          name: name,
          cropType: _cropType,
          areaHectares: area,
          address: address.isEmpty ? null : address,
        );
      } else {
        await notifier.create(
          name: name,
          cropType: _cropType,
          areaHectares: area,
          address: address.isEmpty ? null : address,
        );
      }
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
        title: Text(_isEdit ? 'Editar finca' : 'Registrar finca'),
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
                  label: 'Nombre de la finca',
                  hint: 'Finca El Roble',
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
                  label: 'Área (hectáreas)',
                  hint: '12.5',
                  controller: _areaController,
                  validator: validateArea,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Dirección (opcional)',
                  hint: 'Vereda La Esperanza, Buga',
                  controller: _addressController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppErrorBanner(message: _errorMessage),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _isEdit ? 'Guardar cambios' : 'Registrar finca',
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

