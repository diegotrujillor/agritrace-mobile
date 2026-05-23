// Validator tests for the v1.9.0 free-text farm cropType field.
//
// The validator lives in `lib/utils/validators.dart` so it can be
// exercised without booting the widget tree. Asserts that empty input
// is accepted (the field is optional at the farm level after v1.9.0)
// and that the 255-char upper bound matches the backend Zod limit.

import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/utils/validators.dart';

void main() {
  group('validateOptionalFarmCropType', () {
    test('accepts null', () {
      expect(validateOptionalFarmCropType(null), isNull);
    });

    test('accepts empty / whitespace', () {
      expect(validateOptionalFarmCropType(''), isNull);
      expect(validateOptionalFarmCropType('   '), isNull);
    });

    test('accepts a short free-text value', () {
      expect(validateOptionalFarmCropType('Cacao'), isNull);
      expect(
        validateOptionalFarmCropType('Agricultura de exportación'),
        isNull,
      );
    });

    test('accepts the boundary (exactly 255 chars)', () {
      expect(validateOptionalFarmCropType('a' * 255), isNull);
    });

    test('rejects strings longer than 255 chars', () {
      final result = validateOptionalFarmCropType('a' * 256);
      expect(result, 'El tipo de cultivo es demasiado largo');
    });

    test('trims before measuring length', () {
      // 255 chars surrounded by whitespace must still validate.
      expect(
        validateOptionalFarmCropType('   ${'a' * 255}   '),
        isNull,
      );
    });
  });
}
