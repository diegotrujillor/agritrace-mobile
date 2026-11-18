// Date/time rules for the reminder form (CU-18).
//
// v1.12.1 — reminders now carry a time of day. Kept as pure functions so
// the form stays free of logic and the rules are unit-testable.

/// Default hour for a new reminder: early morning, before field work.
const int kDefaultReminderHour = 7;

/// Default reminder instant: tomorrow at [kDefaultReminderHour]:00 local.
DateTime defaultReminderDateTime(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1, kDefaultReminderHour);

/// Moves [current] to the day of [date] (as returned by `showDatePicker`,
/// i.e. midnight) while keeping the time the user already chose.
DateTime withDate(DateTime current, DateTime date) => DateTime(
      date.year,
      date.month,
      date.day,
      current.hour,
      current.minute,
    );

/// Sets the time of day on [current] while keeping its date.
DateTime withTime(
  DateTime current, {
  required int hour,
  required int minute,
}) =>
    DateTime(current.year, current.month, current.day, hour, minute);

/// Validation message when [at] is not strictly after [now]; `null` if OK.
/// A past instant would never fire as a notification.
String? reminderTimeError(DateTime at, DateTime now) =>
    at.isAfter(now) ? null : 'Elige una hora que aún no haya pasado';
