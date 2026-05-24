// Small, pure text-normalization helpers reused across forms.
//
// Lives outside `constants.dart` (which holds design tokens + enum tables)
// and `validators.dart` (which only returns error messages) to keep the
// dependency direction one-way: forms depend on utils, never the other way.

/// Trims [input], returns `null` when the result is empty, and capitalises
/// the first character of the remainder. Used to normalise free-text fields
/// like `farm.cropType` (v1.9.2 — QA cycle-02) on submit so the saved value
/// is the source of truth, regardless of how the user typed/pasted it.
///
/// Examples:
///   `capitalizeFirstLetter(null)`     → `null`
///   `capitalizeFirstLetter('   ')`    → `null`
///   `capitalizeFirstLetter('cacao')`  → `'Cacao'`
///   `capitalizeFirstLetter('Cacao')`  → `'Cacao'` (idempotent)
///   `capitalizeFirstLetter(' caña ')` → `'Caña'`
String? capitalizeFirstLetter(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
