import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryGreen  = Color(0xFF2D7A3E);
  static const darkGreen     = Color(0xFF1B5028);
  static const lightGreen    = Color(0xFFE8F5E9);
  static const earthBrown    = Color(0xFF6D4C3D);
  static const harvestYellow = Color(0xFFF9A825);
  static const certBlue      = Color(0xFF1976D2);
  static const white         = Color(0xFFFFFFFF);
  static const error         = Color(0xFFD32F2F);
  static const grey          = Color(0xFF757575);
  static const lightGrey     = Color(0xFFF5F5F5);
  static const offlineOrange = Color(0xFFF57C00);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Crop types offered in the **plot** form. Constrained to the MVP pilot
/// region (Valle del Cauca) primary crops plus an `otro` escape hatch. The
/// value is sent verbatim to the backend `cropType` field.
///
/// **v1.9.0 — plot form only.** The farm form now accepts free-text (the
/// farm-level cultivo is informational and can be "Agricultura de
/// exportación" or similar). The plot form still uses this fixed enum so
/// agronomic analytics (yield per crop, sync grouping) keep clean labels.
const List<String> kCropTypes = <String>[
  'cacao',
  'cana_panelera',
  'hortalizas',
  'frutas',
  'otro',
];

/// Human-readable Spanish label for a plot `cropType` wire value.
///
/// Used by `PlotForm` to render the dropdown items with proper accents and
/// capitalisation (the wire value is snake_case / lowercase). New entries
/// must be added here whenever [kCropTypes] grows.
String cropTypeLabel(String wireValue) => switch (wireValue) {
      'cacao' => 'Cacao',
      'cana_panelera' => 'Caña panelera',
      'hortalizas' => 'Hortalizas',
      'frutas' => 'Frutas',
      'otro' => 'Otro',
      _ => wireValue,
    };

/// Maps a free-text farm `cropType` suggestion to a plot enum value when
/// the strings line up (case-insensitive, accent-folded). Returns `null`
/// when there is no match — the plot form then falls back to the default
/// selection.
///
/// Examples: `'Cacao'` → `'cacao'`, `'Caña panelera'` → `'cana_panelera'`.
/// Tolerates the pre-1.9.0 single-word `'caña'` value found in legacy
/// offline rows so an upgrade in place keeps a sensible default.
String? matchPlotCropType(String? suggestion) {
  if (suggestion == null) return null;
  final normalised = suggestion
      .trim()
      .toLowerCase()
      // Drop accents on the few letters we care about (á é í ó ú ñ).
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(' ', '_');
  if (normalised.isEmpty) return null;
  if (kCropTypes.contains(normalised)) return normalised;
  if (normalised == 'cana') return 'cana_panelera';
  return null;
}
