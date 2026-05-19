import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// An inline, centred error message used inside a scrolling detail view.
/// Replaces the identical private `_InlineError` in the farm and plot detail
/// screens.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error, fontSize: 16),
        ),
      ),
    );
  }
}
