import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/models/alert.dart';

void main() {
  group('Alert.fromJson', () {
    test('parses a full reminder payload', () {
      final alert = Alert.fromJson({
        'id': 'a1',
        'type': 'reminder',
        'severity': 'info',
        'title': 'Fertilizar',
        'status': 'pending',
        'createdAt': '2026-05-19T10:00:00.000Z',
        'plotId': 'plot-1',
        'body': 'Abono orgánico',
        'scheduledFor': '2026-06-01T12:00:00.000Z',
      });

      expect(alert.id, 'a1');
      expect(alert.type, AlertType.reminder);
      expect(alert.severity, AlertSeverity.info);
      expect(alert.status, AlertStatus.pending);
      expect(alert.plotId, 'plot-1');
      expect(alert.scheduledFor, isNotNull);
    });

    test('tolerates null optional fields', () {
      final alert = Alert.fromJson({
        'id': 'a2',
        'type': 'weather',
        'severity': 'severe',
        'title': 'Alerta de clima',
        'status': 'sent',
        'createdAt': '2026-05-19T10:00:00.000Z',
        'plotId': null,
        'body': null,
        'scheduledFor': null,
      });

      expect(alert.type, AlertType.weather);
      expect(alert.severity, AlertSeverity.severe);
      expect(alert.plotId, isNull);
      expect(alert.body, isNull);
      expect(alert.scheduledFor, isNull);
    });

    test('falls back to safe defaults on unknown enum values', () {
      final alert = Alert.fromJson({
        'id': 'a3',
        'type': 'nope',
        'severity': 'unknown',
        'title': 'X',
        'status': 'weird',
        'createdAt': '2026-05-19T10:00:00.000Z',
      });

      expect(alert.type, AlertType.reminder);
      expect(alert.severity, AlertSeverity.info);
      expect(alert.status, AlertStatus.pending);
    });
  });

  group('Alert.copyWith', () {
    test('only overrides status, keeping other fields', () {
      final alert = Alert.fromJson({
        'id': 'a4',
        'type': 'reminder',
        'severity': 'warning',
        'title': 'Riego',
        'status': 'pending',
        'createdAt': '2026-05-19T10:00:00.000Z',
      });

      final dismissed = alert.copyWith(status: AlertStatus.dismissed);
      expect(dismissed.status, AlertStatus.dismissed);
      expect(dismissed.title, 'Riego');
      expect(dismissed.severity, AlertSeverity.warning);
    });
  });

  group('enum wire round-trips', () {
    test('AlertType', () {
      for (final t in AlertType.values) {
        expect(AlertType.fromWire(t.wire), t);
      }
    });
    test('AlertStatus', () {
      for (final s in AlertStatus.values) {
        expect(AlertStatus.fromWire(s.wire), s);
      }
    });
  });
}
