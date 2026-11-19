import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

import '../services/local_notification_gateway.dart';
import '../services/reminder_notifications.dart';
import 'database_provider.dart';

/// Platform gateway for OS notifications. Overridden with a fake in tests.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationGateway(),
);

/// Last reconcile failure (`null` = healthy). v1.12.2 — scheduling errors
/// used to be dev.log-only, invisible in release builds.
final reminderSyncErrorProvider = StateProvider<String?>((_) => null);

/// Shared reconciler between the local alerts table and OS notifications.
final reminderNotificationSyncProvider = Provider<ReminderNotificationSync>(
  (ref) => ReminderNotificationSync(
    ref.watch(notificationGatewayProvider),
    onStatus: (error) =>
        ref.read(reminderSyncErrorProvider.notifier).state = error,
  ),
);

/// Whether the OS lets AgriTrace post notifications right now. Invalidate
/// to re-check (screen resume, after a permission prompt).
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationGatewayProvider).areEnabled(),
);

/// Opens this app's system settings page. Overridden in tests.
final appSettingsOpenerProvider = Provider<Future<bool> Function()>(
  (_) => perm.openAppSettings,
);

/// Keeps OS-scheduled reminder notifications in sync with Drift.
///
/// Watched once from the app root (`main.dart`). Every emission of the
/// alerts stream — local create/dismiss/delete, sync pull, login seed, and
/// the logout wipe (empty list → cancel all) — is reconciled through
/// [ReminderNotificationSync.apply].
final reminderNotificationsBindingProvider = Provider<void>((ref) {
  final sync = ref.watch(reminderNotificationSyncProvider);
  final subscription = ref.watch(alertRepositoryProvider).watchAll().listen(
        sync.apply,
        onError: (Object e, StackTrace st) => dev.log(
          'alerts stream failed: $e',
          name: 'notifications',
          error: e,
          stackTrace: st,
        ),
      );
  ref.onDispose(subscription.cancel);
});
