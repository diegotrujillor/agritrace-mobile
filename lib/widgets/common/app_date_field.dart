import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// A read-only, tappable field that shows a formatted date and opens a date
/// picker via [onTap]. Replaces the identical private `_DateField` that lived
/// in the activity and alert form screens.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: AppColors.darkGreen),
            ),
          ),
        ),
      ],
    );
  }
}
