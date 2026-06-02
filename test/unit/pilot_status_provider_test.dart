import 'package:flutter_test/flutter_test.dart';

import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/providers/pilot_status_provider.dart';

User _user({
  bool isDemo = false,
  DateTime? pilotEndsAt,
  UserRole role = UserRole.producer,
}) =>
    User(
      id: 'u1',
      email: 'test@example.com',
      fullName: 'Test Producer',
      phone: '+573001111111',
      role: role,
      isDemo: isDemo,
      pilotEndsAt: pilotEndsAt,
    );

void main() {
  group('PilotStatus.fromUser', () {
    test('null user → exempt', () {
      final s = PilotStatus.fromUser(null);
      expect(s.code, PilotStatusCode.exempt);
      expect(s.isBlocked, isFalse);
    });

    test('admin role → exempt', () {
      final s = PilotStatus.fromUser(_user(role: UserRole.admin));
      expect(s.code, PilotStatusCode.exempt);
      expect(s.isBlocked, isFalse);
    });

    test('isDemo=true → exempt regardless of pilotEndsAt', () {
      final past = DateTime.now().subtract(const Duration(days: 5));
      final s = PilotStatus.fromUser(_user(isDemo: true, pilotEndsAt: past));
      expect(s.code, PilotStatusCode.exempt);
      expect(s.daysRemaining, isNull);
    });

    test('non-demo producer, null pilotEndsAt → notStarted', () {
      final s = PilotStatus.fromUser(_user());
      expect(s.code, PilotStatusCode.notStarted);
      expect(s.isBlocked, isTrue);
    });

    test('pilotEndsAt 1 day in past → expired', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final s = PilotStatus.fromUser(_user(pilotEndsAt: past));
      expect(s.code, PilotStatusCode.expired);
      expect(s.isBlocked, isTrue);
    });

    test('pilotEndsAt 10 days in future → active, daysRemaining ≥ 9', () {
      final future = DateTime.now().add(const Duration(days: 10));
      final s = PilotStatus.fromUser(_user(pilotEndsAt: future));
      expect(s.code, PilotStatusCode.active);
      expect(s.daysRemaining, greaterThanOrEqualTo(9));
      expect(s.isBlocked, isFalse);
    });

    test('pilotEndsAt 2 hours from now → active, daysRemaining = 0', () {
      final soon = DateTime.now().add(const Duration(hours: 2));
      final s = PilotStatus.fromUser(_user(pilotEndsAt: soon));
      expect(s.code, PilotStatusCode.active);
      expect(s.daysRemaining, 0);
    });

    test('cooperative role, no pilot → notStarted (not exempt)', () {
      final s = PilotStatus.fromUser(_user(role: UserRole.cooperative));
      expect(s.code, PilotStatusCode.notStarted);
    });
  });
}
