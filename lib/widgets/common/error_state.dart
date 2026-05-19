import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Full-area error placeholder with a retry action. Replaces the identical
/// private `_ErrorState` in the dashboard and alerts screens.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
