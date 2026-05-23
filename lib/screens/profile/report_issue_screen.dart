import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/feedback.dart';
import '../../providers/feedback_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_labeled_dropdown.dart';

/// CU-28 — Reportar problema desde la app (v1.8.0).
///
/// Lets a pilot user post a bug/feature/other report to `POST /v1/feedback`
/// without leaving the app. The backend converts the payload into a GitHub
/// issue and returns its URL — the screen surfaces that URL in a success
/// dialog so the user can deep-link to the issue if they want.
///
/// Device + app metadata are captured automatically (read-only preview)
/// so the GitHub issue carries reproducible context.
class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

/// Minimum characters required for the message body. Matches the
/// backend's `message` validator (10–5000 in the frozen contract).
const int _kMessageMinChars = 10;

/// Maximum characters accepted by the backend. Used both as the
/// `TextField.maxLength` hint and as a defensive client-side validator.
const int _kMessageMaxChars = 5000;

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  FeedbackCategory _category = FeedbackCategory.bug;
  bool _submitting = false;
  String? _errorMessage;

  /// Captured asynchronously in [initState] and rendered in the read-only
  /// "Información que se enviará" section. `null` while loading.
  String? _appVersion;
  FeedbackDevice? _device;

  @override
  void initState() {
    super.initState();
    _captureMetadata();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Captures `appVersion` from PackageInfo and `device` from DeviceInfo.
  /// iOS is not shipping in MVP (CLAUDE.md "Android-only project") — we
  /// still guard with `Platform.isAndroid` and fall back to safe
  /// placeholders so a future iOS build does not crash here.
  Future<void> _captureMetadata() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      final appVersion = '${pkg.version}+${pkg.buildNumber}';

      final FeedbackDevice device;
      if (kIsWeb) {
        // Web is unsupported (see `storageServiceProvider`) but keep the
        // path safe for tests that may exercise the screen in a host env.
        device = const FeedbackDevice(
          model: 'unknown',
          platform: 'unknown',
          osVersion: 'unknown',
        );
      } else if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        device = FeedbackDevice(
          model: android.model,
          platform: 'android',
          osVersion: 'Android ${android.version.release}',
        );
      } else if (Platform.isIOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        device = FeedbackDevice(
          model: ios.utsname.machine,
          platform: 'ios',
          osVersion: 'iOS ${ios.systemVersion}',
        );
      } else {
        device = const FeedbackDevice(
          model: 'unknown',
          platform: 'unknown',
          osVersion: 'unknown',
        );
      }

      if (!mounted) return;
      setState(() {
        _appVersion = appVersion;
        _device = device;
      });
    } catch (_) {
      // Plugin failures must not block the user from submitting — fall
      // back to placeholders so the form is still usable.
      if (!mounted) return;
      setState(() {
        _appVersion ??= 'desconocida';
        _device ??= const FeedbackDevice(
          model: 'unknown',
          platform: 'unknown',
          osVersion: 'unknown',
        );
      });
    }
  }

  String? _validateMessage(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Cuéntanos qué pasó';
    }
    if (trimmed.length < _kMessageMinChars) {
      return 'Mínimo $_kMessageMinChars caracteres';
    }
    if (trimmed.length > _kMessageMaxChars) {
      return 'Máximo $_kMessageMaxChars caracteres';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final device = _device;
    final appVersion = _appVersion;
    if (device == null || appVersion == null) {
      // Metadata still loading — should be near-instant, but guard anyway.
      setState(() => _errorMessage = 'Cargando información del dispositivo…');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(feedbackServiceProvider).submit(
            message: _messageController.text.trim(),
            category: _category,
            appVersion: appVersion,
            device: device,
          );
      if (!mounted) return;
      await _showSuccessDialog(result);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FeedbackRateLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar el reporte — intenta de nuevo. '
            '(${parseApiError(error)})',
          ),
        ),
      );
    }
  }

  Future<void> _showSuccessDialog(FeedbackSubmitted result) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¡Gracias!'),
        content: Text(
          'Tu reporte fue recibido (#${result.issueNumber}).\n\n'
          'Puedes seguir su estado en GitHub.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.tryParse(result.issueUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('Ver en GitHub'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(title: const Text('Reportar problema')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppLabeledDropdown<FeedbackCategory>(
                  label: 'Tipo de reporte',
                  value: _category,
                  items: const [
                    DropdownMenuItem(
                      value: FeedbackCategory.bug,
                      child: Text('Problema/bug'),
                    ),
                    DropdownMenuItem(
                      value: FeedbackCategory.feature,
                      child: Text('Sugerencia'),
                    ),
                    DropdownMenuItem(
                      value: FeedbackCategory.other,
                      child: Text('Otro'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Mensaje',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _messageController,
                  validator: _validateMessage,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: _kMessageMaxChars,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText:
                        'Describe qué pasó, qué esperabas y los pasos para reproducirlo.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _MetadataPreview(
                  appVersion: _appVersion,
                  device: _device,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppErrorBanner(message: _errorMessage),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Enviar reporte',
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

/// Read-only preview of the metadata that will be attached to the report.
/// Shown so the user knows exactly what is sent — Ley 1581 / RNF-05
/// transparency requirement.
class _MetadataPreview extends StatelessWidget {
  const _MetadataPreview({required this.appVersion, required this.device});

  final String? appVersion;
  final FeedbackDevice? device;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información que se enviará',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetadataRow(
            label: 'Versión',
            value: appVersion ?? 'Cargando…',
          ),
          _MetadataRow(
            label: 'Modelo',
            value: device?.model ?? 'Cargando…',
          ),
          _MetadataRow(
            label: 'Sistema',
            value: device?.osVersion ?? 'Cargando…',
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
