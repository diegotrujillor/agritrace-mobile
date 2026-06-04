import 'package:flutter/material.dart';

import '../models/activity.dart';

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

/// Minutes of zero user gesture activity that trigger a forced logout.
///
/// v1.9.8 — P1 fix. Pilot QA found that JWT access tokens auto-refreshed
/// silently in the background, so a session left untouched on a shared
/// device stayed signed in indefinitely. The client-side
/// [InactivityMonitor] enforces this ceiling: after 20 minutes of no
/// pointer events the monitor calls `AuthService.logout()` and routes
/// the user back to the login screen. The threshold matches the Ley 1581
/// "minimum exposure of personal data on shared devices" guidance for
/// rural pilots where producers often hand-pass a single phone.
const int kInactivityTimeoutMinutes = 20;

/// Public URL for the full Política de Privacidad (Ley 1581).
/// Linked from [RegisterScreen] and [PilotConsentScreen].
const String kPrivacyPolicyUrl = 'https://agritrace.co/privacidad';

/// Units of measure offered in the activity form's `cantidad` dropdown.
/// Kept in sync with the backend Zod enum (`ACTIVITY_UNITS` in
/// agritrace-backend/src/api/activities/activity.validations.ts). A fixed
/// list (not free text) keeps the data aggregatable for future labor reports.
const List<String> kActivityUnits = <String>['kg', 'g', 'L', 'ml', 'unidades'];

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

/// Activity types that trigger the soft duplicate-detection warning on
/// `Registrar actividad` (CU-15). When a producer tries to register one of
/// these activity types for a lote on a calendar day that already has a
/// matching record, the form opens a confirmation [AlertDialog] before
/// persisting. The warning is **soft** — the user can always override and
/// continue.
///
/// **v1.9.6 — pilot QA.** Image #24 from the Valle del Cauca pilot caught a
/// producer logging two `Siembra` rows for the same lote on the same day
/// (user error: thought the first save failed). Siembra is expected once per
/// growing cycle, so a same-day duplicate is almost certainly noise.
///
/// Other activity types (Fertilización, Riego, Control de plagas, Cosecha,
/// Otra) are legitimately repeated within a day on large lotes and stay
/// unrestricted. Add to this set if post-pilot data shows another type with
/// the same pattern (e.g. a future `cosecha_total` once-per-cycle event).
const Set<ActivityType> kDuplicateWarnActivityTypes = <ActivityType>{
  ActivityType.sowing,
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
