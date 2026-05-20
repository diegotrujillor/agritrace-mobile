import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/models/activity.dart';

void main() {
  Map<String, dynamic> activityJson({
    String type = 'pest_control',
    Object? description = 'Aplicación de bioinsumo',
    Object? photoUrl = 'https://cdn.example.com/p.jpg',
  }) =>
      {
        'id': 'act-1',
        'plotId': 'plot-1',
        'type': type,
        'occurredAt': '2026-04-05T08:00:00.000Z',
        'createdAt': '2026-04-05T08:00:01.000Z',
        'description': description,
        'photoUrl': photoUrl,
      };

  group('ActivityType', () {
    test('wire round-trips every enum value', () {
      for (final t in ActivityType.values) {
        expect(ActivityType.fromWire(t.wire), t);
      }
    });

    test('label returns the Spanish UI string for every enum value', () {
      expect(ActivityType.sowing.label, 'Siembra');
      expect(ActivityType.fertilization.label, 'Fertilización');
      expect(ActivityType.irrigation.label, 'Riego');
      expect(ActivityType.pestControl.label, 'Control de plagas');
      expect(ActivityType.harvest.label, 'Cosecha');
      expect(ActivityType.other.label, 'Otra');
    });

    test('fromWire falls back to other on unknown/missing input', () {
      expect(ActivityType.fromWire('nope'), ActivityType.other);
      expect(ActivityType.fromWire(null), ActivityType.other);
    });

    test('pestControl wire value is snake_case', () {
      expect(ActivityType.pestControl.wire, 'pest_control');
    });
  });

  group('Activity.fromJson', () {
    test('parses a full payload', () {
      final activity = Activity.fromJson(activityJson());
      expect(activity.id, 'act-1');
      expect(activity.plotId, 'plot-1');
      expect(activity.type, ActivityType.pestControl);
      expect(activity.occurredAt.isUtc, isTrue);
      expect(activity.createdAt.isUtc, isTrue);
      expect(activity.description, 'Aplicación de bioinsumo');
      expect(activity.photoUrl, 'https://cdn.example.com/p.jpg');
    });

    test('tolerates null optional fields', () {
      final activity = Activity.fromJson(
        activityJson(description: null, photoUrl: null),
      );
      expect(activity.description, isNull);
      expect(activity.photoUrl, isNull);
    });

    test('falls back to other when type is unknown', () {
      final activity = Activity.fromJson(activityJson(type: 'mystery'));
      expect(activity.type, ActivityType.other);
    });
  });

  group('Activity.toJson', () {
    test('round-trips through fromJson preserving every field', () {
      final original = Activity.fromJson(activityJson(type: 'sowing'));
      final round = Activity.fromJson(original.toJson());

      expect(round.id, original.id);
      expect(round.plotId, original.plotId);
      expect(round.type, original.type);
      expect(round.occurredAt, original.occurredAt);
      expect(round.createdAt, original.createdAt);
      expect(round.description, original.description);
      expect(round.photoUrl, original.photoUrl);
    });

    test('serialises type as snake_case wire value', () {
      final activity = Activity.fromJson(activityJson(type: 'pest_control'));
      expect(activity.toJson()['type'], 'pest_control');
    });
  });

  group('Activity.copyWith', () {
    final base = Activity.fromJson(activityJson());

    test('returns identical fields when no overrides given', () {
      final copy = base.copyWith();
      expect(copy.toJson(), base.toJson());
    });

    test('overrides every field independently', () {
      final occurred = DateTime.utc(2027, 1, 1);
      final created = DateTime.utc(2027, 1, 2);
      final copy = base.copyWith(
        id: 'act-2',
        plotId: 'plot-2',
        type: ActivityType.harvest,
        occurredAt: occurred,
        createdAt: created,
        description: 'New',
        photoUrl: 'https://x/y.jpg',
      );
      expect(copy.id, 'act-2');
      expect(copy.plotId, 'plot-2');
      expect(copy.type, ActivityType.harvest);
      expect(copy.occurredAt, occurred);
      expect(copy.createdAt, created);
      expect(copy.description, 'New');
      expect(copy.photoUrl, 'https://x/y.jpg');
    });
  });
}
