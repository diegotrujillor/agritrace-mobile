import 'package:agritrace_mobile/utils/date_format.dart';
import 'package:agritrace_mobile/utils/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultReminderDateTime', () {
    test('is tomorrow at 7:00 local time', () {
      // Arrange
      final now = DateTime(2026, 11, 18, 15, 40);

      // Act
      final result = defaultReminderDateTime(now);

      // Assert
      expect(result, DateTime(2026, 11, 19, kDefaultReminderHour));
    });

    test('rolls over month and year boundaries', () {
      expect(
        defaultReminderDateTime(DateTime(2026, 12, 31, 22)),
        DateTime(2027, 1, 1, kDefaultReminderHour),
      );
    });
  });

  group('withDate / withTime', () {
    test('withDate changes the day but keeps the chosen time', () {
      final current = DateTime(2026, 11, 19, 6, 30);

      // showDatePicker returns midnight of the picked day.
      final result = withDate(current, DateTime(2026, 11, 25));

      expect(result, DateTime(2026, 11, 25, 6, 30));
    });

    test('withTime changes the time but keeps the chosen day', () {
      final current = DateTime(2026, 11, 25, 7);

      final result = withTime(current, hour: 16, minute: 45);

      expect(result, DateTime(2026, 11, 25, 16, 45));
    });
  });

  group('reminderTimeError', () {
    final now = DateTime(2026, 11, 18, 15, 40);

    test('is null for a time in the future', () {
      expect(reminderTimeError(DateTime(2026, 11, 18, 15, 41), now), isNull);
    });

    test('rejects a time that already passed today', () {
      expect(
        reminderTimeError(DateTime(2026, 11, 18, 9), now),
        'Elige una hora que aún no haya pasado',
      );
    });

    test('rejects exactly now', () {
      expect(reminderTimeError(now, now), isNotNull);
    });
  });

  group('formatLocalTime', () {
    test('formats morning hours in 12-hour Colombian style', () {
      expect(formatLocalTime(DateTime(2026, 11, 19, 7)), '7:00 a. m.');
    });

    test('formats afternoon hours with zero-padded minutes', () {
      expect(formatLocalTime(DateTime(2026, 11, 19, 15, 5)), '3:05 p. m.');
    });

    test('midnight is 12 a. m. and noon is 12 p. m.', () {
      expect(formatLocalTime(DateTime(2026, 11, 19)), '12:00 a. m.');
      expect(formatLocalTime(DateTime(2026, 11, 19, 12, 30)), '12:30 p. m.');
    });
  });
}
