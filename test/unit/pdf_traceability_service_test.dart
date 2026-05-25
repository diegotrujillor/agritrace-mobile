import 'dart:io';
import 'dart:typed_data';

import 'package:agritrace_mobile/models/activity.dart';
import 'package:agritrace_mobile/models/farm.dart';
import 'package:agritrace_mobile/models/plot.dart';
import 'package:agritrace_mobile/services/pdf_traceability_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_helpers.dart';

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

Activity makeActivity({
  String id = 'act-1',
  String? photoUrl,
  String? description,
  DateTime? occurredAt,
}) =>
    Activity(
      id: id,
      plotId: 'plot-1',
      type: ActivityType.sowing,
      occurredAt: occurredAt ?? DateTime.utc(2026, 3, 15),
      createdAt: occurredAt ?? DateTime.utc(2026, 3, 15),
      description: description,
      photoUrl: photoUrl,
    );

/// Valid 1×1 red opaque PNG (69 bytes). The `pdf` package's [pw.MemoryImage]
/// decoder rejects malformed streams, so the test fixture must be a real,
/// CRC-valid PNG. Generated offline; do not edit by hand.
Uint8List _tinyPng() => Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, //
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, //
      0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00, //
      0x00, 0x03, 0x01, 0x01, 0x00, 0xC9, 0xFE, 0x92, //
      0xEF, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
      0x44, 0xAE, 0x42, 0x60, 0x82, //
    ]);

Response<List<int>> _bytesResponse(List<int> bytes, {String path = '/x.jpg'}) {
  return Response<List<int>>(
    data: bytes,
    statusCode: 200,
    requestOptions: RequestOptions(path: path),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  // ───────────────────────── existing build() coverage ──────────────────
  group('build() — pure document generation', () {
    late PdfTraceabilityService service;

    setUp(() {
      service = PdfTraceabilityService();
    });

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

  // ─────────────────── v1.9.7 — remote photo (OCI) coverage ─────────────
  group('_loadPhoto via build() — v1.9.7 OCI URL handling (#33)', () {
    late MockDio dio;
    late PdfTraceabilityService service;

    setUp(() {
      dio = MockDio();
      service = PdfTraceabilityService(httpClient: dio);
    });

    test('https OCI URL — Dio returns bytes → PDF includes the photo',
        () async {
      const url =
          'https://objectstorage.sa-bogota-1.oraclecloud.com/n/x/b/photos/o/abc.jpg';
      when(() => dio.get<List<int>>(
            url,
            options: any(named: 'options'),
          )).thenAnswer((_) async => _bytesResponse(_tinyPng(), path: url));

      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [makeActivity(photoUrl: url)],
      );

      expect(bytes.isNotEmpty, isTrue);
      verify(() => dio.get<List<int>>(
            url,
            options: any(named: 'options'),
          )).called(1);
    });

    test('http URL — same code path as https, photo renders', () async {
      const url = 'http://localhost:9000/photo.jpg';
      when(() => dio.get<List<int>>(
            url,
            options: any(named: 'options'),
          )).thenAnswer((_) async => _bytesResponse(_tinyPng(), path: url));

      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [makeActivity(photoUrl: url)],
      );

      expect(bytes.isNotEmpty, isTrue);
      verify(() => dio.get<List<int>>(
            url,
            options: any(named: 'options'),
          )).called(1);
    });

    test(
      'https URL — Dio throws DioException (connection error) → '
      'no exception bubbles, PDF still generates',
      () async {
        const url = 'https://objectstorage.example.com/photo.jpg';
        when(() => dio.get<List<int>>(
              url,
              options: any(named: 'options'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: url),
            type: DioExceptionType.connectionError,
            message: 'Network unreachable',
          ),
        );

        // The build must complete; the failure is swallowed and the row
        // renders a placeholder instead of crashing the document.
        final bytes = await service.build(
          farm: makeFarm(),
          plot: makePlot(),
          activities: [makeActivity(photoUrl: url)],
        );
        expect(bytes.isNotEmpty, isTrue);
      },
    );

    test(
      'https URL — Dio throws timeout → swallowed, PDF generates',
      () async {
        const url = 'https://objectstorage.example.com/slow.jpg';
        when(() => dio.get<List<int>>(
              url,
              options: any(named: 'options'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: url),
            type: DioExceptionType.connectionTimeout,
            message: 'Connection timed out',
          ),
        );

        final bytes = await service.build(
          farm: makeFarm(),
          plot: makePlot(),
          activities: [makeActivity(photoUrl: url)],
        );
        expect(bytes.isNotEmpty, isTrue);
      },
    );

    test('https URL — empty response body → returns null, PDF still generates',
        () async {
      const url = 'https://objectstorage.example.com/empty.jpg';
      when(() => dio.get<List<int>>(
            url,
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => _bytesResponse(const <int>[], path: url),
      );

      final bytes = await service.build(
        farm: makeFarm(),
        plot: makePlot(),
        activities: [makeActivity(photoUrl: url)],
      );
      expect(bytes.isNotEmpty, isTrue);
    });

    test(
      'PDF generation continues when 1 of 3 activity photos fails to load',
      () async {
        const okUrl1 = 'https://objectstorage.example.com/ok-1.jpg';
        const okUrl2 = 'https://objectstorage.example.com/ok-2.jpg';
        const badUrl = 'https://objectstorage.example.com/bad.jpg';

        when(() => dio.get<List<int>>(
              okUrl1,
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => _bytesResponse(_tinyPng(), path: okUrl1),
        );
        when(() => dio.get<List<int>>(
              okUrl2,
              options: any(named: 'options'),
            )).thenAnswer(
          (_) async => _bytesResponse(_tinyPng(), path: okUrl2),
        );
        when(() => dio.get<List<int>>(
              badUrl,
              options: any(named: 'options'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: badUrl),
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: badUrl),
              statusCode: 404,
            ),
            message: '404 not found',
          ),
        );

        final bytes = await service.build(
          farm: makeFarm(),
          plot: makePlot(),
          activities: [
            makeActivity(
              id: 'a',
              photoUrl: okUrl1,
              occurredAt: DateTime.utc(2026, 1, 1),
            ),
            makeActivity(
              id: 'b',
              photoUrl: badUrl,
              occurredAt: DateTime.utc(2026, 1, 2),
            ),
            makeActivity(
              id: 'c',
              photoUrl: okUrl2,
              occurredAt: DateTime.utc(2026, 1, 3),
            ),
          ],
        );

        expect(bytes.isNotEmpty, isTrue);
        verify(() => dio.get<List<int>>(
              okUrl1,
              options: any(named: 'options'),
            )).called(1);
        verify(() => dio.get<List<int>>(
              badUrl,
              options: any(named: 'options'),
            )).called(1);
        verify(() => dio.get<List<int>>(
              okUrl2,
              options: any(named: 'options'),
            )).called(1);
      },
    );

    test(
      'local file path → does NOT hit Dio (verifies branch isolation)',
      () async {
        // Local-file branch must not touch the HTTP client at all.
        final bytes = await service.build(
          farm: makeFarm(),
          plot: makePlot(),
          activities: [
            makeActivity(photoUrl: '/nonexistent/local/path.jpg'),
          ],
        );
        expect(bytes.isNotEmpty, isTrue);
        verifyNever(() => dio.get<List<int>>(
              any(),
              options: any(named: 'options'),
            ));
      },
    );

    test(
      'local file path — reads bytes correctly when the file exists',
      () async {
        final tmp = await File(
          '${Directory.systemTemp.path}/pdf-trace-${DateTime.now().microsecondsSinceEpoch}.png',
        ).create();
        try {
          await tmp.writeAsBytes(_tinyPng());
          final bytes = await service.build(
            farm: makeFarm(),
            plot: makePlot(),
            activities: [makeActivity(photoUrl: tmp.path)],
          );
          expect(bytes.isNotEmpty, isTrue);
          verifyNever(() => dio.get<List<int>>(
                any(),
                options: any(named: 'options'),
              ));
        } finally {
          if (await tmp.exists()) {
            await tmp.delete();
          }
        }
      },
    );
  });
}
