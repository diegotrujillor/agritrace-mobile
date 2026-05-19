import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/farm.dart';
import '../../utils/constants.dart';
import '../common/app_card.dart';

/// List tile for a single [Farm] in the dashboard. Tapping opens the farm
/// detail screen via [onTap].
class FarmCard extends StatelessWidget {
  const FarmCard({super.key, required this.farm, required this.onTap});

  final Farm farm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.agriculture_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farm.name,
                  style: GoogleFonts.inter(
                    color: AppColors.darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${farm.cropType} · ${_formatArea(farm.areaHectares)} ha',
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.grey),
        ],
      ),
    );
  }
}

/// Drops a trailing `.0` so whole hectares read as `12` not `12.0`, while
/// keeping one decimal otherwise (`12.5`).
String _formatArea(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
