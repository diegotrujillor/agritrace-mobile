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

/// Crop types offered in the farm/plot forms. Constrained to the MVP pilot
/// region (Valle del Cauca) primary crops plus an `otro` escape hatch. The
/// value is sent verbatim to the backend `cropType` field.
const List<String> kCropTypes = <String>[
  'cacao',
  'caña',
  'hortalizas',
  'frutas',
  'otro',
];
