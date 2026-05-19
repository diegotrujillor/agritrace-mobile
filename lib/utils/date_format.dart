/// `dd/mm/yyyy` in the local time zone — the format Colombian farmers expect.
///
/// Kept here (rather than a date package) to avoid a new dependency. Replaces
/// the duplicated `formatActivityDate` / `_formatDate` copies that previously
/// lived in widgets, screens and the PDF service. Behaviour is copied exactly
/// from `formatActivityDate` (local time zone, zero-padded day/month).
String formatLocalDate(DateTime date) {
  final local = date.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return '$d/$m/${local.year}';
}
