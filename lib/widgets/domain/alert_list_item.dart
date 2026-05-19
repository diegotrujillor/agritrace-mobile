import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/alert.dart';
import '../../utils/constants.dart';
import '../../utils/date_format.dart';
import '../common/app_card.dart';

/// List tile for a single [Alert]. Severity drives the accent colour;
/// pending alerts expose dismiss/delete actions.
class AlertListItem extends StatelessWidget {
  const AlertListItem({
    super.key,
    required this.alert,
    this.onDismiss,
    this.onDelete,
  });

  final Alert alert;
  final VoidCallback? onDismiss;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(alert.severity);
    final body = alert.body;
    final when = alert.scheduledFor ?? alert.createdAt;
    final isDismissed = alert.status == AlertStatus.dismissed;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(alert.type), color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: GoogleFonts.inter(
                    color: isDismissed ? AppColors.grey : AppColors.darkGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: isDismissed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${alert.type.label} · ${formatLocalDate(when)}',
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 13,
                  ),
                ),
                if (body != null && body.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
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
          if (alert.status != AlertStatus.dismissed && onDismiss != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color: AppColors.primaryGreen,
              tooltip: 'Descartar',
              onPressed: onDismiss,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppColors.grey,
              tooltip: 'Eliminar',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

Color _accentFor(AlertSeverity severity) => switch (severity) {
      AlertSeverity.info => AppColors.certBlue,
      AlertSeverity.warning => AppColors.harvestYellow,
      AlertSeverity.severe => AppColors.error,
    };

IconData _iconFor(AlertType type) => switch (type) {
      AlertType.weather => Icons.cloud_outlined,
      AlertType.reminder => Icons.notifications_active_outlined,
    };
