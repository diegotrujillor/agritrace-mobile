// Pure-function tests for `capitalizeFirstLetter`. Lives in `test/unit/`
// because the helper has no Flutter widget surface — only string in,
// string out — and was introduced in v1.9.2 to fix the QA cycle-02 finca
// `cropType` capitalisation bug (autofill / paste / edit-mode reload that
// `TextCapitalization.sentences` cannot reach).
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/utils/text_format.dart';

void main() {
  group('capitalizeFirstLetter', () {
    test('returns null for null input', () {
      expect(capitalizeFirstLetter(null), isNull);
    });

    test('returns null for empty string', () {
      expect(capitalizeFirstLetter(''), isNull);
    });

    test('returns null for whitespace-only input', () {
      expect(capitalizeFirstLetter('   '), isNull);
      expect(capitalizeFirstLetter('\t  \n'), isNull);
    });

    test('capitalises the first character of a lowercase word', () {
      expect(capitalizeFirstLetter('cacao'), 'Cacao');
    });

    test('is idempotent on an already-capitalised value', () {
      expect(capitalizeFirstLetter('Cacao'), 'Cacao');
    });

    test('trims surrounding whitespace before capitalising', () {
      expect(capitalizeFirstLetter(' caña '), 'Caña');
    });

    test('preserves the rest of the string verbatim', () {
      expect(
        capitalizeFirstLetter('agricultura de exportación'),
        'Agricultura de exportación',
      );
    });

    test('handles single-character input', () {
      expect(capitalizeFirstLetter('a'), 'A');
    });

    test('leaves accented uppercase characters untouched on the tail', () {
      expect(capitalizeFirstLetter('caÑa panelera'), 'CaÑa panelera');
    });
  });
}
