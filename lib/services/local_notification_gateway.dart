import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/constants.dart';
import 'reminder_notifications.dart';

/// Android channel for reminder notifications (CU-18). Users can mute it
/// independently in system settings.
const String kReminderChannelId = 'reminders';
const String kReminderChannelName = 'Recordatorios';
const String kReminderChannelDescription =
    'Avisos de los recordatorios que programas en AgriTrace';

/// Monochrome status-bar icon (`res/drawable/ic_stat_reminder.xml`).
///
/// v1.12.2 — was `@mipmap/ic_launcher`, a full-colour adaptive icon: on a
/// Pixel the alarm fired and the channel was created, yet nothing appeared.
/// Android requires a white-on-transparent small icon. Kept from R8
/// resource shrinking by `res/raw/keep.xml` (looked up by name at runtime).
const String kReminderSmallIcon = 'ic_stat_reminder';

/// Fixed id for the "Probar notificación" check. Re-tapping replaces the
/// previous test notification instead of stacking new ones.
const int kTestNotificationId = 0;

/// [NotificationGateway] backed by `flutter_local_notifications`.
///
/// Fully on-device: no push server, no FCM, no proprietary SDK (principles
/// 1, 2, 7). Scheduled alarms survive reboot and app updates through the
/// plugin's `ScheduledNotificationBootReceiver` (AndroidManifest.xml).
///
/// Uses *inexact* alarms (`inexactAllowWhileIdle`): Android may delay
/// delivery by a few minutes in Doze, which is fine for farm reminders and
/// avoids the restricted `SCHEDULE_EXACT_ALARM` permission.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      kReminderChannelId,
      kReminderChannelName,
      channelDescription: kReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: kReminderSmallIcon,
      color: AppColors.primaryGreen,
    ),
  );

  /// Lazily initializes the plugin exactly once.
  Future<void> _ensureInitialized() => _initialized ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(kReminderSmallIcon),
        ),
      )
      .then((_) {});

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule(PlannedNotification notification) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      // The reminder is an absolute instant, so UTC is exact regardless of
      // the device time zone — no tz database lookup needed.
      scheduledDate: tz.TZDateTime.from(notification.at.toUtc(), tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.alertId,
    );
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _android;
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> areEnabled() async {
    await _ensureInitialized();
    final android = _android;
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> showTest() async {
    await _ensureInitialized();
    await _plugin.show(
      id: kTestNotificationId,
      title: 'AgriTrace',
      body: 'Así se verán tus recordatorios.',
      notificationDetails: _details,
    );
  }
}
