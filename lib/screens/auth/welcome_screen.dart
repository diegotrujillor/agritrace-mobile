import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/route_names.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_button.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const _Logo(),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Certifica tus cultivos y accede a mercados premium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const Spacer(flex: 3),
              AppButton(
                label: 'Iniciar sesión',
                onPressed: () => context.go(Routes.login),
              ),
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => context.go(Routes.register),
                child: const Text(
                  '¿No tienes cuenta? Regístrate',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.white,
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.eco_rounded, color: AppColors.white, size: 72),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AgriTrace',
          style: GoogleFonts.poppins(
            color: AppColors.white,
            fontSize: 40,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
