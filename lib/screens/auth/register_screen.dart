import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../navigation/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../utils/validators.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';
import '../../widgets/common/app_logo_mark.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _consent = false;

  static final Uri _privacyPolicyUrl = Uri.parse(
    'https://github.com/diegotrujillor/agritrace-docs/blob/main/'
    '01-preparacion-mvp/08-legal/01-politica-privacidad.md',
  );

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(_privacyPolicyUrl, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) return;
    await ref.read(authProvider.notifier).register(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          privacyConsent: _consent,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState    = ref.watch(authProvider);
    final isLoading    = authState.isLoading;
    final errorMessage =
        authState.hasError ? parseApiError(authState.error) : null;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v1.9.3 — QA cycle-03: bump brand mark 2× (40 → 80 px)
                // AND move it to the RIGHT, aligned at the same vertical
                // level as the "Crear cuenta" title (Row with
                // spaceBetween). Title text + style unchanged so the
                // existing widget tests keep matching their text finders.
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crear cuenta',
                            style: GoogleFonts.inter(
                              color: AppColors.darkGreen,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Regístrate como productor agrícola',
                            style: TextStyle(
                              color: AppColors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const AppLogoMark(size: 80),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  label: 'Nombre completo',
                  hint: 'Juan Gómez',
                  controller: _nameController,
                  validator: validateFullName,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  // v1.9.1 — PDF QA cycle-01 #1. Autofill (Android) often
                  // appends a trailing space that the submit-time `.trim()`
                  // never reveals to the user, leaving them confused at the
                  // visible whitespace. This formatter strips trailing
                  // whitespace ONLY on paste/autofill bursts (length grew
                  // by more than one character in a single change), so
                  // typing "Diego Trujillo" letter-by-letter still works.
                  inputFormatters: const [_TrimTrailingWhitespaceOnBurst()],
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Teléfono',
                  hint: '+57 310 123 4567',
                  controller: _phoneController,
                  validator: validatePhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Email',
                  hint: 'tu@email.com',
                  controller: _emailController,
                  validator: validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  // v1.9.0 — bug #4 fix. Identical pattern to LoginScreen.
                  onChanged: (_) =>
                      ref.read(authProvider.notifier).clearError(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Contraseña',
                  hint: 'Mínimo 8 caracteres',
                  controller: _passwordController,
                  validator: validatePassword,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppErrorBanner(message: errorMessage),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consent,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (v) =>
                          setState(() => _consent = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            const Text(
                              'Acepto la ',
                              style: TextStyle(
                                  color: AppColors.grey, fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: _openPrivacyPolicy,
                              child: const Text(
                                'Política de Privacidad',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Text(
                              ' y el tratamiento de mis datos (Ley 1581).',
                              style: TextStyle(
                                  color: AppColors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Registrarse',
                  onPressed: (isLoading || !_consent) ? null : _submit,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(Routes.login),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                    ),
                    child: const Text(
                      '¿Ya tienes cuenta? Inicia sesión',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Strips trailing whitespace from the new value ONLY when the change looks
/// like a paste or autofill burst — i.e. the length grew by more than one
/// character in a single edit. Manual keystrokes (typing a space between two
/// words) are left untouched, which preserves the ability to type names like
/// "Diego Trujillo".
///
/// Added in v1.9.1 to fix PDF QA cycle-01 #1: Android autofill appended a
/// trailing space that the submit-time `.trim()` never surfaced to the user.
class _TrimTrailingWhitespaceOnBurst extends TextInputFormatter {
  const _TrimTrailingWhitespaceOnBurst();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final grew = newValue.text.length - oldValue.text.length;
    if (grew <= 1) return newValue; // single keystroke — never touch.
    final trimmed = newValue.text.replaceFirst(RegExp(r'\s+$'), '');
    if (trimmed == newValue.text) return newValue; // nothing to strip.
    return TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
      composing: TextRange.empty,
    );
  }
}
