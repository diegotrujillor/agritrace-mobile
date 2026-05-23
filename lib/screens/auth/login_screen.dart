import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../utils/validators.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_error_banner.dart';
import '../../widgets/common/app_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'AgriTrace',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Iniciar sesión',
                    style: GoogleFonts.inter(
                      color: AppColors.darkGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppInput(
                  label: 'Email',
                  hint: 'tu@email.com',
                  controller: _emailController,
                  validator: validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  // v1.9.0 — bug #4 fix. Wipe the error banner the moment
                  // the producer edits the field. Without this, a previous
                  // "Credenciales incorrectas" stays glued to the screen
                  // even after the user fixes the typo.
                  onChanged: (_) =>
                      ref.read(authProvider.notifier).clearError(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppInput(
                  label: 'Contraseña',
                  hint: '••••••••',
                  controller: _passwordController,
                  validator: validatePassword,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) =>
                      ref.read(authProvider.notifier).clearError(),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppErrorBanner(message: errorMessage),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Iniciar sesión',
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go(Routes.register),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text(
                    '¿No tienes cuenta? Regístrate',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
