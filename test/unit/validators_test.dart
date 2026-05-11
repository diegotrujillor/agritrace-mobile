import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('returns null for valid email', () {
      expect(validateEmail('test@example.com'), isNull);
    });
    test('returns error for empty value', () {
      expect(validateEmail(''), isNotNull);
    });
    test('returns error for null value', () {
      expect(validateEmail(null), isNotNull);
    });
    test('returns error for missing @', () {
      expect(validateEmail('notanemail'), isNotNull);
    });
    test('returns error for missing domain', () {
      expect(validateEmail('user@'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('returns null for valid password (mixed case + digit)', () {
      expect(validatePassword('SecurePass123'), isNull);
    });
    test('returns error for empty password', () {
      expect(validatePassword(''), isNotNull);
    });
    test('returns error for password shorter than 8 chars', () {
      expect(validatePassword('Short1a'), isNotNull);
    });
    test('returns error for 8 digits only (no letters)', () {
      expect(validatePassword('12345678'), isNotNull);
    });
    test('returns error for missing uppercase', () {
      expect(validatePassword('lowercase123'), isNotNull);
    });
    test('returns error for missing digit', () {
      expect(validatePassword('NoDigitsHere'), isNotNull);
    });
    test('returns null for exactly 8 chars when complexity is satisfied', () {
      expect(validatePassword('Abcdef12'), isNull);
    });
  });

  group('validateFullName', () {
    test('returns null for valid name', () {
      expect(validateFullName('Juan Gómez'), isNull);
    });
    test('returns error for empty name', () {
      expect(validateFullName(''), isNotNull);
    });
    test('returns error for whitespace only', () {
      expect(validateFullName('   '), isNotNull);
    });
    test('returns error for name shorter than 3 chars', () {
      expect(validateFullName('Jo'), isNotNull);
    });
  });

  group('validatePhone', () {
    test('returns null for valid Colombian phone with country code', () {
      expect(validatePhone('+57 310 123 4567'), isNull);
    });
    test('returns null for plain digits', () {
      expect(validatePhone('3101234567'), isNull);
    });
    test('returns error for empty phone', () {
      expect(validatePhone(''), isNotNull);
    });
    test('returns error for too-short phone', () {
      expect(validatePhone('123'), isNotNull);
    });
    test('returns error for null', () {
      expect(validatePhone(null), isNotNull);
    });
  });
}
