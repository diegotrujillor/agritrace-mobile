// Validator tests for the v1.9.0 plot cropType enum field.
//
// `validatePlotCropType` takes the allow-list explicitly to keep its
// import surface minimal (no `utils/constants.dart` pull). Tests
// exercise the production enum (`kCropTypes`) plus a synthetic short
// list to prove the validator does not hardcode any value.

import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/utils/constants.dart';
import 'package:agritrace_mobile/utils/validators.dart';

void main() {
  group('validatePlotCropType', () {
    test('rejects null with the Spanish select-one message', () {
      expect(
        validatePlotCropType(null, kCropTypes),
        'Selecciona un tipo de cultivo',
      );
    });

    test('rejects empty / whitespace', () {
      expect(
        validatePlotCropType('', kCropTypes),
        'Selecciona un tipo de cultivo',
      );
      expect(
        validatePlotCropType('   ', kCropTypes),
        'Selecciona un tipo de cultivo',
      );
    });

    test('accepts every value in the production enum', () {
      for (final crop in kCropTypes) {
        expect(
          validatePlotCropType(crop, kCropTypes),
          isNull,
          reason: '$crop should be a valid enum value',
        );
      }
    });

    test('accepts the v1.9.0 wire values verbatim', () {
      // Sanity check that the enum contract from the prompt actually
      // landed in production. If this fires, the dropdown wire values
      // drifted from the backend contract.
      expect(kCropTypes, contains('cacao'));
      expect(kCropTypes, contains('cana_panelera'));
      expect(kCropTypes, contains('hortalizas'));
      expect(kCropTypes, contains('frutas'));
      expect(kCropTypes, contains('otro'));
    });

    test('rejects values not in the allow-list', () {
      expect(
        validatePlotCropType('zanahoria', kCropTypes),
        'Tipo de cultivo no válido',
      );
      // The pre-1.9.0 single-word `caña` is no longer accepted on the
      // wire — only `cana_panelera` survives.
      expect(
        validatePlotCropType('caña', kCropTypes),
        'Tipo de cultivo no válido',
      );
    });

    test('honours a custom allow-list', () {
      const onlyCacao = ['cacao'];
      expect(validatePlotCropType('cacao', onlyCacao), isNull);
      expect(
        validatePlotCropType('frutas', onlyCacao),
        'Tipo de cultivo no válido',
      );
    });
  });

  group('cropTypeLabel', () {
    test('renders human-readable Spanish labels for every enum value', () {
      expect(cropTypeLabel('cacao'), 'Cacao');
      expect(cropTypeLabel('cana_panelera'), 'Caña panelera');
      expect(cropTypeLabel('hortalizas'), 'Hortalizas');
      expect(cropTypeLabel('frutas'), 'Frutas');
      expect(cropTypeLabel('otro'), 'Otro');
    });

    test('echoes unknown wire values verbatim', () {
      // Defensive: an older offline DB might still carry a value that
      // the v1.9.0 enum doesn't know. Render it as-is rather than crash.
      expect(cropTypeLabel('zanahoria'), 'zanahoria');
    });
  });

  group('matchPlotCropType', () {
    test('returns null for null/empty input', () {
      expect(matchPlotCropType(null), isNull);
      expect(matchPlotCropType(''), isNull);
      expect(matchPlotCropType('   '), isNull);
    });

    test('matches each label back to its wire value (case-insensitive)', () {
      expect(matchPlotCropType('Cacao'), 'cacao');
      expect(matchPlotCropType('CACAO'), 'cacao');
      expect(matchPlotCropType('Caña panelera'), 'cana_panelera');
      expect(matchPlotCropType('caña panelera'), 'cana_panelera');
      expect(matchPlotCropType('Hortalizas'), 'hortalizas');
    });

    test('tolerates the legacy single-word `caña`', () {
      expect(matchPlotCropType('caña'), 'cana_panelera');
    });

    test('returns null when the input does not line up', () {
      expect(matchPlotCropType('Agricultura de exportación'), isNull);
      expect(matchPlotCropType('zanahoria'), isNull);
    });
  });
}
