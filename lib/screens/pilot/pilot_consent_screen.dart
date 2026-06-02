import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_logo_mark.dart';

/// One-time consent screen shown after the first login / register when
/// [AuthAuthenticated.pilotConsentGiven] is false.
///
/// Presents a summary of what data AgriTrace collects and a link to the full
/// Política de Privacidad at [kPrivacyPolicyUrl]. The GoRouter redirect in
/// `app_router.dart` routes here automatically; tapping "Acepto y continuar"
/// calls [AuthNotifier.markPilotConsentGiven] and the router re-evaluates.
class PilotConsentScreen extends ConsumerStatefulWidget {
  const PilotConsentScreen({super.key});

  @override
  ConsumerState<PilotConsentScreen> createState() => _PilotConsentScreenState();
}

class _PilotConsentScreenState extends ConsumerState<PilotConsentScreen> {
  bool _loading = false;

  static final _policyUri = Uri.parse(kPrivacyPolicyUrl);

  Future<void> _openPolicy() async {
    await launchUrl(_policyUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).markPilotConsentGiven();
    // Router redirect triggers automatically when auth state updates.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Center(child: AppLogoMark(size: 80)),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Antes de comenzar',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AgriTrace necesita tu consentimiento para tratar tus datos '
                'personales conforme a la Ley 1581 de 2012 (Habeas Data, Colombia).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qué datos usamos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._dataPoints.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 18, color: AppColors.primaryGreen),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                p,
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.grey, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'No vendemos tus datos ni los usamos para publicidad.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: GestureDetector(
                  onTap: _openPolicy,
                  child: const Text(
                    'Leer Política de Privacidad completa →',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Acepto y continuar',
                onPressed: _loading ? null : _accept,
                isLoading: _loading,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  child: const Text(
                    'No acepto — cerrar sesión',
                    style: TextStyle(color: AppColors.grey, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

const _dataPoints = [
  'Nombre, email y teléfono — para identificarte y darte soporte.',
  'Datos de finca, lotes y actividades agrícolas — son tuyos, para trazabilidad.',
  'Registros de acceso (fecha, IP, dispositivo) — seguridad y auditoría Ley 1581.',
  'Almacenado en Colombia (Oracle Cloud, Bogotá). Sin transferencia internacional.',
];
