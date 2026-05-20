import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses a full payload', () {
      final user = User.fromJson({
        'id': 'u-1',
        'email': 'a@b.com',
        'fullName': 'Ana Buitrago',
        'phone': '+57 300 123 4567',
        'role': 'cooperative',
      });

      expect(user.id, 'u-1');
      expect(user.email, 'a@b.com');
      expect(user.fullName, 'Ana Buitrago');
      expect(user.phone, '+57 300 123 4567');
      expect(user.role, UserRole.cooperative);
    });

    test('defaults phone to empty string when missing', () {
      final user = User.fromJson({
        'id': 'u-2',
        'email': 'a@b.com',
        'fullName': 'X',
        'role': 'producer',
      });

      expect(user.phone, '');
    });

    test('falls back to producer when role is unknown', () {
      final user = User.fromJson({
        'id': 'u-3',
        'email': 'a@b.com',
        'fullName': 'X',
        'phone': '',
        'role': 'martian',
      });

      expect(user.role, UserRole.producer);
    });
  });

  group('User.toJson', () {
    test('round-trips through fromJson', () {
      const original = User(
        id: 'u-1',
        email: 'a@b.com',
        fullName: 'Ana',
        phone: '+57 300',
        role: UserRole.exporter,
      );

      final round = User.fromJson(original.toJson());

      expect(round.id, original.id);
      expect(round.email, original.email);
      expect(round.fullName, original.fullName);
      expect(round.phone, original.phone);
      expect(round.role, original.role);
    });
  });

  group('User.copyWith', () {
    const base = User(
      id: 'u-1',
      email: 'a@b.com',
      fullName: 'Ana',
      phone: '+57 300',
      role: UserRole.producer,
    );

    test('returns identical fields when no overrides given', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.email, base.email);
      expect(copy.fullName, base.fullName);
      expect(copy.phone, base.phone);
      expect(copy.role, base.role);
    });

    test('overrides every field independently', () {
      final copy = base.copyWith(
        id: 'u-2',
        email: 'new@b.com',
        fullName: 'New',
        phone: '999',
        role: UserRole.buyer,
      );
      expect(copy.id, 'u-2');
      expect(copy.email, 'new@b.com');
      expect(copy.fullName, 'New');
      expect(copy.phone, '999');
      expect(copy.role, UserRole.buyer);
    });
  });

  group('AuthResponse.fromJson', () {
    Map<String, dynamic> validEnvelope() => {
          'success': true,
          'data': {
            'accessToken': 'A',
            'refreshToken': 'R',
            'user': {
              'id': 'u-1',
              'email': 'a@b.com',
              'fullName': 'Ana',
              'phone': '300',
              'role': 'producer',
            },
          },
        };

    test('unwraps the data envelope into AuthResponse', () {
      final auth = AuthResponse.fromJson(validEnvelope());
      expect(auth.accessToken, 'A');
      expect(auth.refreshToken, 'R');
      expect(auth.user.id, 'u-1');
      expect(auth.user.role, UserRole.producer);
    });

    test('throws FormatException when success is false', () {
      expect(
        () => AuthResponse.fromJson({'success': false}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when data is missing', () {
      expect(
        () => AuthResponse.fromJson({'success': true}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
