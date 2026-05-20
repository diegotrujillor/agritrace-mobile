import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/models/farm.dart';

void main() {
  Map<String, dynamic> farmJson({
    Object? areaHectares = 12.5,
    Object? latitude = 3.42,
    Object? longitude = -76.5,
    Object? address = 'Vereda La Esperanza',
  }) =>
      {
        'id': 'f-1',
        'name': 'Finca La Esperanza',
        'cropType': 'cacao',
        'areaHectares': areaHectares,
        'createdAt': '2026-03-01T00:00:00.000Z',
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

  group('Farm.fromJson', () {
    test('parses a full payload', () {
      final farm = Farm.fromJson(farmJson());
      expect(farm.id, 'f-1');
      expect(farm.name, 'Finca La Esperanza');
      expect(farm.cropType, 'cacao');
      expect(farm.areaHectares, 12.5);
      expect(farm.createdAt.isUtc, isTrue);
      expect(farm.latitude, 3.42);
      expect(farm.longitude, -76.5);
      expect(farm.address, 'Vereda La Esperanza');
    });

    test('tolerates null optional fields', () {
      final farm = Farm.fromJson(farmJson(
        latitude: null,
        longitude: null,
        address: null,
      ));
      expect(farm.latitude, isNull);
      expect(farm.longitude, isNull);
      expect(farm.address, isNull);
    });

    test('defaults areaHectares to 0 when missing/null', () {
      final farm = Farm.fromJson(farmJson(areaHectares: null));
      expect(farm.areaHectares, 0);
    });

    test('parses numeric strings (areaHectares, lat, lon)', () {
      final farm = Farm.fromJson(farmJson(
        areaHectares: '7.5',
        latitude: '3.1',
        longitude: '-76.2',
      ));
      expect(farm.areaHectares, 7.5);
      expect(farm.latitude, 3.1);
      expect(farm.longitude, -76.2);
    });
  });

  group('Farm.toJson', () {
    test('round-trips through fromJson preserving every field', () {
      final original = Farm.fromJson(farmJson());
      final round = Farm.fromJson(original.toJson());

      expect(round.id, original.id);
      expect(round.name, original.name);
      expect(round.cropType, original.cropType);
      expect(round.areaHectares, original.areaHectares);
      expect(round.createdAt, original.createdAt);
      expect(round.latitude, original.latitude);
      expect(round.longitude, original.longitude);
      expect(round.address, original.address);
    });

    test('serialises null optional fields as null', () {
      final farm = Farm.fromJson(farmJson(
        latitude: null,
        longitude: null,
        address: null,
      ));
      final json = farm.toJson();
      expect(json['latitude'], isNull);
      expect(json['longitude'], isNull);
      expect(json['address'], isNull);
    });
  });

  group('Farm.copyWith', () {
    final base = Farm.fromJson(farmJson());

    test('returns identical fields when no overrides given', () {
      final copy = base.copyWith();
      expect(copy.toJson(), base.toJson());
    });

    test('overrides every field independently', () {
      final ts = DateTime.utc(2027, 2, 2);
      final copy = base.copyWith(
        id: 'f-2',
        name: 'Otra finca',
        cropType: 'panela',
        areaHectares: 99,
        createdAt: ts,
        latitude: 0,
        longitude: 0,
        address: 'X',
      );
      expect(copy.id, 'f-2');
      expect(copy.name, 'Otra finca');
      expect(copy.cropType, 'panela');
      expect(copy.areaHectares, 99);
      expect(copy.createdAt, ts);
      expect(copy.latitude, 0);
      expect(copy.longitude, 0);
      expect(copy.address, 'X');
    });
  });
}
