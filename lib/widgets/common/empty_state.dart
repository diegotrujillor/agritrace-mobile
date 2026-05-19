import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';

/// Centred empty-state placeholder. Replaces the per-screen `_EmptyState`
/// (icon + title + subtitle) and the simpler `_NoActivities` / `_NoPlots`
/// (subtitle only) widgets.
///
/// [icon] and [title] are optional so the subtitle-only screens render
/// exactly as before. [padding] preserves each screen's original spacing;
/// [subtitleHeight] is `1.5` only for the rich variant (matching the
/// original `_EmptyState`).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.subtitle,
    this.icon,
    this.title,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.subtitleHeight,
  });

  final IconData? icon;
  final String? title;
  final String subtitle;
  final EdgeInsetsGeometry padding;
  final double? subtitleHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 80, color: AppColors.primaryGreen),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 16,
                height: subtitleHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
