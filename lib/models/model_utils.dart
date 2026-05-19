/// Shared parsing helpers for model `fromJson` factories.
///
/// Replaces the identical private `_toDouble` previously duplicated in
/// `farm.dart` and `plot.dart`. Behaviour is copied exactly.
library;

/// Accepts the numeric value whether the API serialises it as a JSON number
/// or a string (some backends emit decimals as strings). Returns null for
/// missing/unparseable input rather than throwing.
double? toDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
