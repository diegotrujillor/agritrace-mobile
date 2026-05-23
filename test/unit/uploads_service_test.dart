// Unit tests for `lib/services/uploads_service.dart` — the v0.6.0
// `POST /v1/uploads/photos` multipart wrapper.
//
// Strategy mirrors `feedback_service_test.dart`: mock `ApiService.client`
// (Dio), drive the real `UploadsService` against the mock, and assert
// envelope unwrapping + the four error-mapping branches in the contract.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/upload.dart';
import 'package:agritrace_mobile/services/uploads_service.dart';

import '_helpers.dart';

Response<Map<String, dynamic>> _createdResponse(Map<String, dynamic> data) {
  return Response<Map<String, dynamic>>(
    data: data,
    statusCode: 201,
    requestOptions: RequestOptions(path: '/uploads/photos'),
  );
}

List<int> _fakeJpegBytes(int size) =>
    Uint8List.fromList(List<int>.filled(size, 0xFF));

void main() {
  late MockApiService api;
  late MockDio dio;
  late UploadsService service;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    api = MockApiService();
    dio = MockDio();
    when(() => api.client).thenReturn(dio);
    service = UploadsService(api);
  });

  group('uploadPhoto()', () {
    test('builds a multipart body with the `photo` field on /uploads/photos',
        () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/uploads/photos',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => _createdResponse(envelope({
          'url': 'https://cdn.agritrace.co/photos/abc.jpg',
          'key': 'photos/abc.jpg',
          'size': 12345,
          'contentType': 'image/jpeg',
        })),
      );

      await service.uploadPhoto(
        bytes: _fakeJpegBytes(1024),
        filename: 'IMG_001.jpg',
        contentType: 'image/jpeg',
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/uploads/photos',
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured.single as FormData;

      // The single field must be named `photo` exactly (matches multer's
      // `single('photo')` in the backend handler).
      expect(captured.files, hasLength(1));
      expect(captured.files.first.key, 'photo');
      expect(captured.files.first.value.filename, 'IMG_001.jpg');
    });

    test('parses 201 envelope into UploadResponse', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/uploads/photos',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => _createdResponse(envelope({
          'url': 'https://cdn.agritrace.co/photos/x.jpg',
          'key': 'photos/x.jpg',
          'size': 42,
          'contentType': 'image/jpeg',
        })),
      );

      final result = await service.uploadPhoto(
        bytes: _fakeJpegBytes(10),
        filename: 'x.jpg',
        contentType: 'image/jpeg',
      );

      expect(result.url, 'https://cdn.agritrace.co/photos/x.jpg');
      expect(result.key, 'photos/x.jpg');
      expect(result.size, 42);
      expect(result.contentType, 'image/jpeg');
    });

    test('throws UploadTooLargeException locally when bytes exceed 5 MB',
        () async {
      // Hit the local guard before any Dio call — the service must NOT
      // make the request when it can prove client-side that the body is
      // already over budget.
      expect(
        () => service.uploadPhoto(
          bytes: _fakeJpegBytes(kMaxUploadBytes + 1),
          filename: 'huge.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(
          isA<UploadTooLargeException>().having(
            (e) => e.userMessage,
            'userMessage',
            kUploadTooLargeMessage,
          ),
        ),
      );
      verifyNever(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ));
    });

    test('maps HTTP 413 to UploadTooLargeException', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/uploads/photos',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/uploads/photos'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/uploads/photos'),
            statusCode: 413,
          ),
        ),
      );

      expect(
        service.uploadPhoto(
          bytes: _fakeJpegBytes(1024),
          filename: 'x.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(isA<UploadTooLargeException>()),
      );
    });

    test('maps HTTP 429 to UploadRateLimitException with Spanish copy',
        () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/uploads/photos',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/uploads/photos'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/uploads/photos'),
            statusCode: 429,
          ),
        ),
      );

      expect(
        service.uploadPhoto(
          bytes: _fakeJpegBytes(1024),
          filename: 'x.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(
          isA<UploadRateLimitException>().having(
            (e) => e.userMessage,
            'userMessage',
            kUploadRateLimitMessage,
          ),
        ),
      );
    });

    test('propagates DioException on 502 upstream failures', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/uploads/photos',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/uploads/photos'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/uploads/photos'),
            statusCode: 502,
          ),
        ),
      );

      expect(
        service.uploadPhoto(
          bytes: _fakeJpegBytes(1024),
          filename: 'x.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('throws FormatException when server returns success:false', () async {
      when(() => dio.post<Map<String, dynamic>>(
            '/uploads/photos',
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _createdResponse(
            {'success': false, 'error': 'invalid input'},
          ));

      expect(
        service.uploadPhoto(
          bytes: _fakeJpegBytes(10),
          filename: 'x.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', 'invalid input'),
        ),
      );
    });
  });

  group('UploadResponse.fromJson', () {
    test('parses the contracted fields', () {
      final r = UploadResponse.fromJson({
        'url': 'https://cdn/x.jpg',
        'key': 'x.jpg',
        'size': 100,
        'contentType': 'image/png',
      });
      expect(r.url, 'https://cdn/x.jpg');
      expect(r.size, 100);
      expect(r.contentType, 'image/png');
    });

    test('throws when url is missing', () {
      expect(
        () => UploadResponse.fromJson({
          'key': 'x.jpg',
          'size': 100,
          'contentType': 'image/png',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('tolerates num size (Dio sometimes hands back num for big ints)', () {
      final r = UploadResponse.fromJson({
        'url': 'https://cdn/x.jpg',
        'key': 'x.jpg',
        'size': 12345.0,
        'contentType': 'image/jpeg',
      });
      expect(r.size, 12345);
    });
  });
}
