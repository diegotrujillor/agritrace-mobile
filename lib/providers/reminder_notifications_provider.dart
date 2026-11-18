import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_notification_gateway.dart';
import '../services/reminder_notifications.dart';
import 'database_provider.dart';

/// Platform gateway for OS notifications. Overridden with a fake in tests.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationGateway(),
);

/// Shared reconciler between the local alerts table and OS notifications.
final reminderNotificationSyncProvider = Provider<ReminderNotificationSync>(
  (ref) => ReminderNotificationSync(ref.watch(notificationGatewayProvider)),
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
