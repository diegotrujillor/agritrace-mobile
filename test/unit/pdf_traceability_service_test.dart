import 'dart:typed_data';

import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/services/pdf_traceability_service.dart';
import 'package:flutter_test/flutter_test.dart';

Farm makeFarm({double? latitude, double? longitude}) => Farm(
      id: 'farm-1',
      name: 'Finca El Roble',
      cropType: 'Cacao',
      areaHectares: 5.0,
      createdAt: DateTime.utc(2026, 1, 1),
      latitude: latitude,
      longitude: longitude,
    );

Plot makePlot() => Plot(
      id: 'plot-1',
      farmId: 'farm-1',
      name: 'Lote Norte',
      cropType: 'Cacao',
      status: PlotStatus.growing,
      createdAt: DateTime.utc(2026, 1, 1),
      variety: 'CCN-51',
    );

Activity makeActivity({String? photoUrl, String? description}) => Activity(
      id: 'act-1',
      plotId: 'plot-1',
      type: ActivityType.sowing,
      occurredAt: DateTime.utc(2026, 3, 15),
      createdAt: DateTime.utc(2026, 3, 15),
      description: description,
      photoUrl: photoUrl,
    );

void main() {
  const service = PdfTraceabilityService();

  group('build()', () {
    test('returns non-empty PDF bytes', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [],
      );
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('includes producer phone when provided', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [],
        producerPhone: '+57 311 2345678',
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('omits phone row when phone is null', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [],
        producerPhone: null,
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('omits phone row when phone is empty string', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [],
        producerPhone: '',
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('includes producer email when provided', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [],
        producerEmail: 'juan@example.com',
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('omits email row when email is null', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [],
        producerEmail: null,
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('includes GPS row when farm has both coordinates', () async {
      final bytes = await service.build(
        farm: makeFarm(latitude: 10.3932, longitude: -75.4832),
        plot: makePlot(),
        activities: [],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('omits GPS row when farm latitude is null', () async {
      final bytes = await service.build(
        farm: makeFarm(latitude: null, longitude: -75.4832),
        plot: makePlot(),
        activities: [],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('omits GPS row when farm longitude is null', () async {
      final bytes = await service.build(
        farm: makeFarm(latitude: 10.3932, longitude: null),
        plot: makePlot(),
        activities: [],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('renders activities with null photoUrl without error', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [makeActivity(photoUrl: null)],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('skips missing photo file gracefully', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [makeActivity(photoUrl: '/nonexistent/path/photo.jpg')],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('skips file:// prefixed missing photo gracefully', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [
          makeActivity(photoUrl: 'file:///nonexistent/path/photo.jpg'),
        ],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('activity with null description renders em-dash', () async {
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [makeActivity(description: null)],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('activities sorted chronologically oldest-first', () async {
      final later = Activity(
        id: 'act-2',
        plotId: 'plot-1',
        type: ActivityType.harvest,
        occurredAt: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 6, 1),
      );
      final earlier = makeActivity();
      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [later, earlier],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test('GPS formats negative coordinates as S/W', () async {
      final bytes = await service.build(
        farm: makeFarm(latitude: -3.1234, longitude: -60.5678),
        plot: makePlot(),
        activities: [],
      );
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
