import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/reminder_notifications_provider.dart';
import '../../utils/constants.dart';

/// v1.12.2 — tells the producer when reminders cannot reach the phone.
///
/// Two failure modes, both previously silent:
/// - notifications disabled for the app (permission denied / switched off)
///   → "Activar" opens the app's system settings;
/// - the last reconcile with the OS scheduler failed.
///
/// Re-checks the permission whenever the app resumes, so returning from
/// system settings clears the banner without a manual refresh.
class NotificationStatusBanner extends ConsumerStatefulWidget {
  const NotificationStatusBanner({super.key});

  @override
  ConsumerState<NotificationStatusBanner> createState() =>
      _NotificationStatusBannerState();
}

class _NotificationStatusBannerState
    extends ConsumerState<NotificationStatusBanner> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationsEnabledProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(notificationsEnabledProvider).valueOrNull;
    final syncError = ref.watch(reminderSyncErrorProvider);

    if (isEnabled == false) {
      return _BannerCard(
        title: 'Notificaciones desactivadas',
        message: 'Tus recordatorios no sonarán en este teléfono.',
        actionLabel: 'Activar',
        onAction: () => ref.read(appSettingsOpenerProvider)(),
      );
    }
    if (syncError != null) {
      return const _BannerCard(
        title: 'Avisos no programados',
        message: 'No se pudieron programar los avisos de tus recordatorios. '
            'Abre de nuevo la app para reintentar.',
      );
    }
    return const SizedBox.shrink();
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: ListTile(
        leading: const Icon(
          Icons.notifications_off_outlined,
          color: AppColors.error,
        ),
        title: Text(title),
        subtitle: Text(message),
        trailing: label == null
            ? null
            : TextButton(onPressed: onAction, child: Text(label)),
      ),
    );
  }
}

/// AppBar action that fires one notification immediately, so the producer
/// can confirm reminders will be visible without waiting for one to fire.
class TestNotificationButton extends ConsumerWidget {
  const TestNotificationButton({super.key});

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final gateway = ref.read(notificationGatewayProvider);
    try {
      final isEnabled = await gateway.areEnabled();
      if (!isEnabled) {
        ref.invalidate(notificationsEnabledProvider);
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Activa las notificaciones de AgriTrace para recibir avisos.',
            ),
            action: SnackBarAction(
              label: 'Activar',
              onPressed: () => ref.read(appSettingsOpenerProvider)(),
            ),
          ),
        );
        return;
      }
      await gateway.showTest();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Notificación de prueba enviada. Revisa la barra de estado.',
          ),
        ),
      );
    } catch (e, st) {
      dev.log(
        'test notification failed: $e',
        name: 'notifications',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('No se pudo mostrar la notificación de prueba.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Probar notificación',
      icon: const Icon(
        Icons.notifications_active_outlined,
        color: AppColors.white,
      ),
      onPressed: () => _onPressed(context, ref),
    );
  }
}
