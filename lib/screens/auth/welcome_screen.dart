import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/route_names.dart';
import '../../utils/constants.dart';
import '../../widgets/common/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                variant: AppButtonVariant.light,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go(Routes.register),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                ),
                child: const Text(
                  '¿No tienes cuenta? Regístrate',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
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
        SvgPicture.asset(
          'assets/brand/agritrace-logo-white.svg',
          width: 96,
          height: 96,
          semanticsLabel: 'AgriTrace',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AgriTrace',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 40,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
