import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/activity.dart';
import '../../../models/upload.dart';
import '../../../providers/uploads_provider.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_format.dart';
import '../../../utils/error_parser.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_date_field.dart';
import '../../../widgets/common/app_error_banner.dart';
import '../../../widgets/common/app_input.dart';
import '../../../widgets/common/app_labeled_dropdown.dart';
import '../../../widgets/common/authenticated_network_image.dart';

/// Shared form body for creating and editing an activity. Renders the 4
/// fields (type / occurred-on date / optional note / optional photo) and
/// delegates persistence to [onSubmit].
///
/// **v1.9.0 — photo capture:** replaces the previous "paste URL"
/// text-field with an `image_picker` flow (camera + gallery). On submit
/// the form first uploads the selected file via [uploadsServiceProvider]
/// (`POST /v1/uploads/photos`) and then calls [onSubmit] with the
/// resulting `url`. If the upload fails, [onSubmit] is NOT called — the
/// user can fix and retry without losing the rest of the form.
///
/// [onSubmit] is `async` so the form can show the spinner while the parent
/// performs the network call (create or update) and pop on success. If the
/// callback throws, the form re-enables the button and surfaces the
/// parsed error in the embedded banner.
class ActivityForm extends ConsumerStatefulWidget {
  const ActivityForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initialType = ActivityType.sowing,
    this.initialOccurredAt,
    this.initialDescription,
    this.initialPhotoUrl,
    this.imagePicker,
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

  /// Pre-filled photo URL (edit mode). Displayed as the initial preview
  /// when present; the user can replace it with a fresh camera/gallery
  /// capture which will then re-upload.
  final String? initialPhotoUrl;

  /// Optional [ImagePicker] override — exists purely for widget tests so
  /// they can swap in a fake without touching the real platform channel.
  /// Production usage leaves this null.
  final ImagePicker? imagePicker;

  @override
  ConsumerState<ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends ConsumerState<ActivityForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late ImagePicker _picker;

  late ActivityType _type;
  late DateTime _occurredAt;
  bool _submitting = false;
  String? _errorMessage;

  /// Locally selected photo (camera or gallery). When non-null, takes
  /// precedence over [_uploadedUrl] / [widget.initialPhotoUrl] on submit
  /// — we re-upload to get a fresh URL.
  XFile? _pickedPhoto;

  /// URL of the most recent successful upload, or the [initialPhotoUrl]
  /// pre-filled by the edit screen. Sent as `photoUrl` on submit when
  /// the user did NOT pick a new photo.
  String? _uploadedUrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _occurredAt = widget.initialOccurredAt ?? DateTime.now();
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _uploadedUrl = widget.initialPhotoUrl;
    _picker = widget.imagePicker ?? ImagePicker();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
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

  /// Wraps [ImagePicker.pickImage] with a shared error-handling shell so
  /// camera- and gallery-paths look identical to the user. `maxWidth`
  /// caps the long edge so a typical phone shot stays well under the
  /// backend's 5 MB limit even before any re-encoding.
  Future<void> _pickFrom(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file == null) return; // user cancelled
      if (!mounted) return;
      setState(() {
        _pickedPhoto = file;
        // Drop any previous uploaded URL — we'll re-upload on submit.
        _uploadedUrl = null;
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir la foto: $e')),
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedPhoto = null;
      _uploadedUrl = null;
    });
  }

  /// MIME inference from the file-name extension. `image_picker` does
  /// not surface contentType, and the backend Zod validator only accepts
  /// `image/jpeg` and `image/png` — anything else returns 400.
  String _inferContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Photo upload happens FIRST so a failed upload doesn't leave a
      // stale activity row behind. If the upload fails, we re-enable the
      // button + show a banner — the rest of the form survives untouched.
      String? photoUrl = _uploadedUrl;
      final picked = _pickedPhoto;
      if (picked != null) {
        try {
          final bytes = await File(picked.path).readAsBytes();
          final uploads = ref.read(uploadsServiceProvider);
          final result = await uploads.uploadPhoto(
            bytes: bytes,
            filename: picked.name,
            contentType: _inferContentType(picked.name),
          );
          // Persist the authenticated read URL (`<API_BASE>/uploads/
          // photos/<id>`) — never the direct OCI path. The bucket is
          // private since backend v0.7.0; reads go through the backend
          // with JWT + ownership check (Ley 1581).
          photoUrl = uploads.urlFor(result.id);
          // Cache so a retry of the form does not re-upload.
          _uploadedUrl = photoUrl;
        } on UploadRateLimitException catch (e) {
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _errorMessage = e.userMessage;
          });
          messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
          return;
        } on UploadTooLargeException catch (e) {
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _errorMessage = e.userMessage;
          });
          messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
          return;
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _errorMessage =
                'No se pudo subir la foto: ${parseApiError(e)}';
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No se pudo subir la foto. Intenta de nuevo.'),
            ),
          );
          return;
        }
      }

      await widget.onSubmit(
        type: _type,
        occurredAt: _occurredAt,
        description: description.isEmpty ? null : description,
        photoUrl: photoUrl,
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

  Widget _buildPhotoSection() {
    final picked = _pickedPhoto;
    final existingUrl = _uploadedUrl;
    final hasPhoto = picked != null || existingUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto (opcional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (hasPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: picked != null
                ? Image.file(
                    File(picked.path),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : AuthenticatedNetworkImage(
                    url: existingUrl!,
                    height: 160,
                    width: double.infinity,
                  ),
          ),
        if (hasPhoto) const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _pickFrom(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Tomar foto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => _pickFrom(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
          ],
        ),
        if (hasPhoto) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _submitting ? null : _removePhoto,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            label: const Text(
              'Quitar foto',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
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
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildPhotoSection(),
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
