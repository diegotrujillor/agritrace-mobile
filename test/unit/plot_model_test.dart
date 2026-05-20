import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/models/plot.dart';

void main() {
  Map<String, dynamic> plotJson({
    String status = 'growing',
    Object? variety = 'Tcs-95',
    Object? areaHectares = 1.5,
  }) =>
      {
        'id': 'p-1',
        'farmId': 'f-1',
        'name': 'Lote norte',
        'cropType': 'cacao',
        'status': status,
        'createdAt': '2026-04-01T00:00:00.000Z',
        'variety': variety,
        'areaHectares': areaHectares,
      };

  group('PlotStatus', () {
    test('label returns the Spanish UI string for every enum value', () {
      expect(PlotStatus.planning.label, 'Planificación');
      expect(PlotStatus.growing.label, 'En crecimiento');
      expect(PlotStatus.ready.label, 'Listo para cosecha');
      expect(PlotStatus.harvested.label, 'Cosechado');
    });

    test('fromName round-trips every enum value', () {
      for (final s in PlotStatus.values) {
        expect(PlotStatus.fromName(s.name), s);
      }
    });

    test('fromName falls back to planning on unknown', () {
      expect(PlotStatus.fromName('mystery'), PlotStatus.planning);
      expect(PlotStatus.fromName(null), PlotStatus.planning);
    });
  });

  group('Plot.fromJson', () {
    test('parses a full payload', () {
      final plot = Plot.fromJson(plotJson());
      expect(plot.id, 'p-1');
      expect(plot.farmId, 'f-1');
      expect(plot.name, 'Lote norte');
      expect(plot.cropType, 'cacao');
      expect(plot.status, PlotStatus.growing);
      expect(plot.createdAt.isUtc, isTrue);
      expect(plot.variety, 'Tcs-95');
      expect(plot.areaHectares, 1.5);
    });

    test('tolerates null optional fields', () {
      final plot = Plot.fromJson(
        plotJson(variety: null, areaHectares: null),
      );
      expect(plot.variety, isNull);
      expect(plot.areaHectares, isNull);
    });

    test('parses areaHectares from string (numeric coercion)', () {
      final plot = Plot.fromJson(plotJson(areaHectares: '2.25'));
      expect(plot.areaHectares, 2.25);
    });

    test('falls back to planning when status is unknown', () {
      final plot = Plot.fromJson(plotJson(status: 'nope'));
      expect(plot.status, PlotStatus.planning);
    });
  });

  group('Plot.toJson', () {
    test('round-trips through fromJson preserving every field', () {
      final original = Plot.fromJson(plotJson(status: 'ready'));
      final round = Plot.fromJson(original.toJson());

      expect(round.id, original.id);
      expect(round.farmId, original.farmId);
      expect(round.name, original.name);
      expect(round.cropType, original.cropType);
      expect(round.status, original.status);
      expect(round.createdAt, original.createdAt);
      expect(round.variety, original.variety);
      expect(round.areaHectares, original.areaHectares);
    });

    test('serialises null optional fields as null', () {
      final plot = Plot.fromJson(plotJson(variety: null, areaHectares: null));
      final json = plot.toJson();
      expect(json['variety'], isNull);
      expect(json['areaHectares'], isNull);
    });
  });

  group('Plot.copyWith', () {
    final base = Plot.fromJson(plotJson());

    test('returns identical fields when no overrides given', () {
      final copy = base.copyWith();
      expect(copy.toJson(), base.toJson());
    });

    test('overrides every field independently', () {
      final ts = DateTime.utc(2027, 1, 1);
      final copy = base.copyWith(
        id: 'p-2',
        farmId: 'f-2',
        name: 'Lote sur',
        cropType: 'café',
        status: PlotStatus.harvested,
        createdAt: ts,
        variety: 'Castillo',
        areaHectares: 9.9,
      );
      expect(copy.id, 'p-2');
      expect(copy.farmId, 'f-2');
      expect(copy.name, 'Lote sur');
      expect(copy.cropType, 'café');
      expect(copy.status, PlotStatus.harvested);
      expect(copy.createdAt, ts);
      expect(copy.variety, 'Castillo');
      expect(copy.areaHectares, 9.9);
    });
  });
}
