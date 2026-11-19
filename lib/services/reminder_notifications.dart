import 'dart:async';
import 'dart:developer' as dev;

import '../models/alert.dart';

/// One OS-level notification derived from a pending reminder [Alert].
///
/// v1.12.0 — reminders (CU-18 / RF-09) used to be list-only: nothing fired
/// on the phone at `scheduledFor`. This value object is the bridge between
/// the Drift `alerts` table and the platform scheduler.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.alertId,
    required this.title,
    required this.at,
    this.body,
  });

  /// Android notification id — see [notificationIdFor].
  final int id;
  final String alertId;
  final String title;
  final String? body;

  /// Absolute instant the notification should fire.
  final DateTime at;

  /// Identity used to detect "plan unchanged" and skip OS round-trips.
  String get signature =>
      '$id|$alertId|${at.toUtc().toIso8601String()}|$title|${body ?? ''}';
}

/// Platform port for scheduling notifications. The production adapter is
/// `LocalNotificationGateway` (flutter_local_notifications); tests inject a
/// fake so the planning/reconcile logic stays pure-Dart.
abstract class NotificationGateway {
  Future<void> cancelAll();
  Future<void> schedule(PlannedNotification notification);

  /// Asks the OS for permission to post notifications (Android 13+).
  /// Returns `true` when granted or not required.
  Future<bool> requestPermission();

  /// Whether the OS currently lets the app post notifications (app-level
  /// switch / POST_NOTIFICATIONS). Never prompts.
  Future<bool> areEnabled();

  /// Posts one notification immediately so the producer can check that
  /// reminders will be visible on this phone.
  Future<void> showTest();
}

/// Receives the outcome of each reconcile: `null` on success, a short
/// error description on failure.
typedef ReminderSyncStatusListener = void Function(String? error);

const int _fnvOffsetBasis = 0x811c9dc5;
const int _fnvPrime = 0x01000193;
const int _mask32 = 0xffffffff;
const int _mask31 = 0x7fffffff;

/// Stable, non-negative 31-bit notification id for an alert UUID.
///
/// Android notification ids are Java `int`s; FNV-1a gives a deterministic
/// value across app restarts (Dart's `String.hashCode` is not guaranteed
/// stable between runs).
int notificationIdFor(String alertId) {
  var hash = _fnvOffsetBasis;
  for (final unit in alertId.codeUnits) {
    hash = ((hash ^ unit) * _fnvPrime) & _mask32;
  }
  return hash & _mask31;
}

/// Pure planner: which alerts deserve an OS notification right now.
///
/// Only `reminder` alerts that are still `pending` and scheduled strictly
/// after [now]. Past-due reminders are not fired retroactively — they stay
/// visible in the Alertas list.
List<PlannedNotification> planReminderNotifications(
  List<Alert> alerts, {
  required DateTime now,
}) {
  return [
    for (final alert in alerts)
      if (alert.type == AlertType.reminder &&
          alert.status == AlertStatus.pending &&
          alert.scheduledFor != null &&
          alert.scheduledFor!.isAfter(now))
        PlannedNotification(
          id: notificationIdFor(alert.id),
          alertId: alert.id,
          title: alert.title,
          body: alert.body,
          at: alert.scheduledFor!,
        ),
  ];
}

/// Reconciles OS-scheduled notifications with the current alert list.
///
/// Called on every emission of the local alerts stream, so create, dismiss,
/// delete, sync pull, login and logout (wipe → empty list) are all covered
/// by one code path. Strategy: cancel all + reschedule the full plan —
/// trivially correct for the handful of reminders a producer keeps, and it
/// avoids tracking per-id state that could drift from the OS.
class ReminderNotificationSync {
  ReminderNotificationSync(
    this._gateway, {
    DateTime Function()? clock,
    ReminderSyncStatusListener? onStatus,
  })  : _clock = clock ?? DateTime.now,
        _onStatus = onStatus;

  final NotificationGateway _gateway;
  final DateTime Function() _clock;
  final ReminderSyncStatusListener? _onStatus;

  /// Signature of the last plan successfully pushed to the OS; `null`
  /// forces the next [apply] to hit the gateway.
  String? _appliedSignature;

  /// Tail of the serialization chain so overlapping stream emissions never
  /// interleave cancel/schedule calls.
  Future<void> _tail = Future<void>.value();

  /// Schedules notifications for [alerts]; never throws (plugin failures
  /// are logged, reported via `onStatus`, and retried on the next emission).
  Future<void> apply(List<Alert> alerts) {
    final next = _tail.then((_) => _applyNow(alerts));
    _tail = next;
    return next;
  }

  Future<void> _applyNow(List<Alert> alerts) async {
    final plan = planReminderNotifications(alerts, now: _clock());
    final signature = plan.map((n) => n.signature).join('\n');
    if (signature == _appliedSignature) return;

    try {
      await _gateway.cancelAll();
      for (final notification in plan) {
        await _gateway.schedule(notification);
      }
      _appliedSignature = signature;
      _onStatus?.call(null);
    } catch (e, st) {
      _appliedSignature = null;
      // v1.12.2 — surfaced to the UI: release builds drop dev.log output,
      // so a silent failure here left reminders mute with no trace.
      _onStatus?.call(e.toString());
      dev.log(
        'reminder notification sync failed: $e',
        name: 'notifications',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<bool> requestPermission() => _gateway.requestPermission();
}
