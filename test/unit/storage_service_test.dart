import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/services/storage_service.dart';

/// `StorageService` accepts a [FlutterSecureStorage] via its constructor,
/// so we can mock the dependency directly instead of going through the
/// platform method channel. This keeps the test pure-Dart and isolates
/// the service's wiring (key names, concurrent writes) from the plugin.
class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backing;
  late StorageService service;

  setUp(() {
    backing = _MockSecureStorage();
    service = StorageService(backing);
  });

  group('saveTokens', () {
    test('writes access_token and refresh_token under their keys', () async {
      when(() => backing.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await service.saveTokens(accessToken: 'A1', refreshToken: 'R1');

      verify(() => backing.write(key: 'access_token', value: 'A1')).called(1);
      verify(() => backing.write(key: 'refresh_token', value: 'R1')).called(1);
    });
  });

  group('getAccessToken / getRefreshToken', () {
    test('reads each token under its dedicated key', () async {
      when(() => backing.read(key: 'access_token'))
          .thenAnswer((_) async => 'A1');
      when(() => backing.read(key: 'refresh_token'))
          .thenAnswer((_) async => 'R1');

      expect(await service.getAccessToken(), 'A1');
      expect(await service.getRefreshToken(), 'R1');
    });

    test('returns null when keys are absent', () async {
      when(() => backing.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
    });
  });

  group('deleteTokens', () {
    test('deletes both keys', () async {
      when(() => backing.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await service.deleteTokens();

      verify(() => backing.delete(key: 'access_token')).called(1);
      verify(() => backing.delete(key: 'refresh_token')).called(1);
    });
  });

  // v1.9.11 — Offline-friendly cold start. The user snapshot is persisted
  // alongside the tokens so [AuthNotifier.build] can short-circuit the
  // network probe when the device has no coverage.
  group('user snapshot (v1.9.11)', () {
    const sampleUser = User(
      id: 'user-1',
      email: 'test@test.com',
      fullName: 'Test User',
      phone: '+57 300 000 0000',
      role: UserRole.producer,
    );

    test('saveUserSnapshot writes JSON-encoded User under the snapshot key',
        () async {
      when(() => backing.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await service.saveUserSnapshot(sampleUser);

      verify(() => backing.write(
            key: 'user_snapshot',
            value: jsonEncode(sampleUser.toJson()),
          )).called(1);
    });

    test('getUserSnapshot decodes a stored JSON User', () async {
      when(() => backing.read(key: 'user_snapshot'))
          .thenAnswer((_) async => jsonEncode(sampleUser.toJson()));

      final result = await service.getUserSnapshot();

      expect(result, isNotNull);
      expect(result!.id, 'user-1');
      expect(result.email, 'test@test.com');
      expect(result.role, UserRole.producer);
    });

    test('getUserSnapshot returns null when key is absent', () async {
      when(() => backing.read(key: 'user_snapshot'))
          .thenAnswer((_) async => null);

      expect(await service.getUserSnapshot(), isNull);
    });

    test('getUserSnapshot returns null on corrupted JSON (does not throw)',
        () async {
      when(() => backing.read(key: 'user_snapshot'))
          .thenAnswer((_) async => 'not-json');

      expect(await service.getUserSnapshot(), isNull);
    });

    test('deleteUserSnapshot removes the snapshot key', () async {
      when(() => backing.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await service.deleteUserSnapshot();

      verify(() => backing.delete(key: 'user_snapshot')).called(1);
    });
  });

  group('deleteAll', () {
    test('deletes tokens, last_user_id, and user_snapshot keys', () async {
      when(() => backing.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await service.deleteAll();

      verify(() => backing.delete(key: 'access_token')).called(1);
      verify(() => backing.delete(key: 'refresh_token')).called(1);
      verify(() => backing.delete(key: 'last_user_id')).called(1);
      // v1.9.11 — the snapshot must be wiped alongside the tokens so a
      // logged-out device retains no trace of the previous account.
      verify(() => backing.delete(key: 'user_snapshot')).called(1);
    });
  });
}
