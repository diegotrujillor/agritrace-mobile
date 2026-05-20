import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/activity.dart';
import '../../utils/constants.dart';
import '../../utils/date_format.dart';
import '../common/app_card.dart';

/// List tile for a single [Activity] in a plot's timeline. Shows the activity
/// type, the date it occurred and an optional note. Tapping opens the edit
/// form via [onTap] (optional). [onLongPress] is used by the timeline to
/// surface a "Editar / Eliminar" contextual bottom sheet (CU-16 + CU-17).
class ActivityListItem extends StatelessWidget {
  const ActivityListItem({
    super.key,
    required this.activity,
    this.onTap,
    this.onLongPress,
  });

  final Activity activity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final description = activity.description;
    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(activity.type),
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.type.label,
                  style: GoogleFonts.inter(
                    color: AppColors.darkGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatLocalDate(activity.occurredAt),
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 14,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.darkGreen,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.grey),
        ],
      ),
    );
  }
}

IconData _iconFor(ActivityType type) => switch (type) {
      ActivityType.sowing => Icons.grass_outlined,
      ActivityType.fertilization => Icons.science_outlined,
      ActivityType.irrigation => Icons.water_drop_outlined,
      ActivityType.pestControl => Icons.bug_report_outlined,
      ActivityType.harvest => Icons.agriculture_outlined,
      ActivityType.other => Icons.event_note_outlined,
    };
