import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// A labelled dropdown form field. Replaces the identical private
/// `_LabeledDropdown<T>` (activity + plot form screens) and the
/// structurally-identical `_CropTypeDropdown` (farm form screen).
///
/// [onChanged] is only invoked with a non-null selection, matching the
/// original behaviour.
class AppLabeledDropdown<T> extends StatelessWidget {
  const AppLabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

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
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
