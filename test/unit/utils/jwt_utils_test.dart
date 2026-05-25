import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/utils/jwt_utils.dart';

/// Builds a fake JWT with the given payload. The header and signature are
/// dummies — these tests target the offline-friendly `exp` heuristic, which
/// by design does NOT verify the signature.
String _makeJwt(Map<String, dynamic> payload) {
  String b64(Map<String, dynamic> m) {
    final raw = utf8.encode(jsonEncode(m));
    // Strip padding so we exercise the [base64Url.normalize] code path
    // inside [jwtExpiry] — production tokens are often un-padded.
    return base64Url.encode(raw).replaceAll('=', '');
  }

  final header = b64({'alg': 'HS256', 'typ': 'JWT'});
  final body = b64(payload);
  // The signature is opaque to the parser; use a fixed dummy.
  return '$header.$body.signature-ignored';
}

void main() {
  group('jwtExpiry', () {
    test('returns a future DateTime when exp is in the future', () {
      final futureSeconds = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final token = _makeJwt({'sub': 'user-1', 'exp': futureSeconds});

      final result = jwtExpiry(token);

      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('returns a past DateTime when exp is in the past', () {
      final pastSeconds = DateTime.utc(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final token = _makeJwt({'sub': 'user-1', 'exp': pastSeconds});

      final result = jwtExpiry(token);

      expect(result, isNotNull);
      expect(result!.year, 2020);
      expect(result.isBefore(DateTime.now().toUtc()), isTrue);
    });

    test('returns null on a malformed token (not three segments)', () {
      expect(jwtExpiry('not.a.jwt.extra'), isNull);
      expect(jwtExpiry('only-one-segment'), isNull);
      expect(jwtExpiry(''), isNull);
    });

    test('returns null when the payload has no exp claim', () {
      final token = _makeJwt({'sub': 'user-1'});

      expect(jwtExpiry(token), isNull);
    });

    test(
      'tolerates base64Url payloads that need re-padding',
      () {
        // The helper always strips padding; verify the parser tolerates
        // un-padded base64Url because the production backend emits that form.
        final futureSeconds = DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000;
        final token = _makeJwt({'sub': 'user-1', 'exp': futureSeconds});

        expect(jwtExpiry(token), isNotNull);
      },
    );

    test('does NOT verify the signature (signature segment is ignored)', () {
      final futureSeconds = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final token = _makeJwt({'sub': 'user-1', 'exp': futureSeconds});
      // Replace the signature with garbage — parser must still succeed
      // because this is a client-side heuristic, not server-side validation.
      final tampered = '${token.split('.').sublist(0, 2).join('.')}.deadbeef';

      expect(jwtExpiry(tampered), isNotNull);
    });
  });

  group('jwtIsExpired', () {
    test('returns false when exp is well in the future', () {
      final futureSeconds = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final token = _makeJwt({'sub': 'user-1', 'exp': futureSeconds});

      expect(jwtIsExpired(token), isFalse);
    });

    test('returns true when exp is in the past', () {
      final pastSeconds = DateTime.utc(2020, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final token = _makeJwt({'sub': 'user-1', 'exp': pastSeconds});

      expect(jwtIsExpired(token), isTrue);
    });

    test('treats malformed tokens as expired', () {
      expect(jwtIsExpired('not.a.jwt'), isTrue);
      expect(jwtIsExpired(''), isTrue);
    });

    test(
      'applies skew so a token expiring within the buffer counts as expired',
      () {
        // exp is 10 s in the future, but skew defaults to 30 s -> expired.
        final almostExpiredSeconds = DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 10))
                .millisecondsSinceEpoch ~/
            1000;
        final token = _makeJwt({'sub': 'user-1', 'exp': almostExpiredSeconds});

        expect(jwtIsExpired(token), isTrue);
        // With a 0 s skew the same token is still valid.
        expect(jwtIsExpired(token, skew: Duration.zero), isFalse);
      },
    );
  });
}
