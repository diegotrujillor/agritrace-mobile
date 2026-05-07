import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Displays a red banner with an error [message]. Renders nothing when
/// [message] is null, so callers can pipe in nullable error state directly.
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.error, fontSize: 16),
      ),
    );
  }
}
