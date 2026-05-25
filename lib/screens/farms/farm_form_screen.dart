import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../models/farm.dart';
import '../../navigation/route_names.dart';
import '../../providers/farms_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../utils/text_format.dart';
import '../../utils/validators.dart';
import '../../widgets/common/app_logo_mark.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';

/// Create / edit a farm. When [farm] is null this is a create form; otherwise
/// the fields are pre-filled and submit issues a `PUT`.
///
/// **v1.9.0 — UX changes:**
///  - `cropType` is a free-text field (optional, max 255 chars). The
///    backend Zod validator was relaxed in v0.6.0 to accept any string.
///  - A "Capturar ubicación GPS" button uses `geolocator` to record the
///    farmer's current position. Skipping it just omits the lat/lng on
///    submit — the rest of the form still validates and posts.
///  - On successful **create** (not edit) the user is auto-navigated to
///    `PlotFormScreen` with the new `farmId` pre-set so the typical
///    onboarding flow (finca → primer lote) is one screen shorter.
class FarmFormScreen extends ConsumerStatefulWidget {
  const FarmFormScreen({super.key, this.farm});

  final Farm? farm;

  @override
  ConsumerState<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends ConsumerState<FarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cropTypeController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();

  bool _submitting = false;
  bool _capturingGps = false;
  String? _errorMessage;
  double? _latitude;
  double? _longitude;

  bool get _isEdit => widget.farm != null;

  @override
  void initState() {
    super.initState();
    final farm = widget.farm;
    if (farm != null) {
      _nameController.text = farm.name;
      _cropTypeController.text = farm.cropType;
      _areaController.text = farm.areaHectares.toString();
      _addressController.text = farm.address ?? '';
      _latitude = farm.latitude;
      _longitude = farm.longitude;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cropTypeController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Asks for runtime location permission and captures one fix via
  /// [Geolocator.getCurrentPosition]. UX is "best-effort": any failure
  /// (permission denied, service off, timeout) surfaces a snackbar but
  /// never blocks the submit — the lat/lng simply stay null.
  Future<void> _captureGps() async {
    if (_capturingGps) return;
    setState(() => _capturingGps = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Step 1: device-level location services must be on.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text(
            'Activa la ubicación del dispositivo para capturar GPS.',
          )),
        );
        return;
      }
      // Step 2: app-level permission. Request if not yet granted.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text(
            'Permiso de ubicación requerido para capturar GPS.',
          )),
        );
        return;
      }
      // Step 3: actual fix. Medium accuracy is enough for a farm centroid
      // and shaves a few seconds off vs. `best` on rural connectivity.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo capturar GPS: $e')),
      );
    } finally {
      if (mounted) setState(() => _capturingGps = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    // v1.9.2 — QA cycle-02: normalise on save (source of truth). Autofill,
    // paste, or edit-mode reload could land an uncapitalised value that
    // `TextCapitalization.sentences` would never fix on its own.
    // `capitalizeFirstLetter` returns null for empty input so the optional
    // backend field is preserved when the producer skipped it.
    final cropType = capitalizeFirstLetter(_cropTypeController.text);
    final area = double.parse(_areaController.text.trim().replaceAll(',', '.'));
    final address = _addressController.text.trim();
    final notifier = ref.read(farmsProvider.notifier);

    try {
      if (_isEdit) {
        await notifier.updateFarm(
          id: widget.farm!.id,
          name: name,
          cropType: cropType,
          areaHectares: area,
          address: address.isEmpty ? null : address,
          latitude: _latitude,
          longitude: _longitude,
        );
        // v1.9.3 — P1 fix. Mirrors the pattern already in
        // `plot_edit_screen.dart`: invalidate BOTH the single-farm
        // lookup (so the detail header re-reads the freshly-persisted
        // value when the user pops back) AND the dashboard list (so
        // the FarmCard re-renders with the new crop type). Without
        // this, the detail screen stayed stuck on the previous
        // `cropType` even though the dashboard reflected the change —
        // because `farmProvider(id)` is a FutureProvider.family whose
        // cached snapshot is independent of the FarmsNotifier list.
        ref.invalidate(farmProvider(widget.farm!.id));
        ref.invalidate(farmsProvider);
        if (!mounted) return;
        context.pop();
        return;
      }
      // Create flow — capture the new farm and auto-navigate to the
      // plot form so the producer can add their first lote in the same
      // session. `go` (not `push`) replaces the create-farm route in
      // the stack so a back-press from PlotFormScreen lands on Dashboard.
      final created = await notifier.create(
        name: name,
        cropType: cropType,
        areaHectares: area,
        address: address.isEmpty ? null : address,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      // `extra` carries the farm-level crop-type suggestion so the plot
      // form can pre-select the matching enum value (see
      // `matchPlotCropType`). `Routes.plotNew` reads the `farmId`.
      context.go(
        Routes.plotNew(created.id),
        extra: created.cropType,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = parseApiError(error);
      });
    }
  }

  String _gpsLabel() {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} capturado';
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
                // v1.9.4 — QA hotfix: centered brand mark below the AppBar.
                // Mirrors the same "header logo" pattern added to
                // `plot_edit_screen.dart` so create + edit finca screens
                // surface the same identity strip the producer expects.
                // v1.9.5 — duplicate bottom-left logo removed; this is now
                // the only AppLogoMark on the screen.
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Center(
                    child: AppLogoMark(size: 80),
                  ),
                ),
                AppInput(
                  label: 'Nombre de la finca',
                  hint: 'Finca El Roble',
                  controller: _nameController,
                  validator: validateRequiredText,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Tipo de cultivo (opcional)',
                  hint: 'Ej. Agricultura de exportación',
                  controller: _cropTypeController,
                  validator: validateOptionalFarmCropType,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
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
                  textCapitalization: TextCapitalization.sentences,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _capturingGps ? null : _captureGps,
                  icon: _capturingGps
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _latitude != null && _longitude != null
                        ? 'Recapturar ubicación GPS'
                        : 'Capturar ubicación GPS',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _gpsLabel(),
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
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
