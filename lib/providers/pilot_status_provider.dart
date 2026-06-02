import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'auth_provider.dart';

/// Computed pilot-window status for the authenticated user.
///
/// Derived from [User.pilotEndsAt] + [User.isDemo] stored in [authProvider].
/// The router reads this to gate navigation; the countdown banner uses
/// [daysRemaining] to decide when to show the amber warning strip.
enum PilotStatusCode {
  /// Admin role or [User.isDemo] flag — no pilot window applies.
  exempt,

  /// Pilot is active; [PilotStatus.daysRemaining] is set.
  active,

  /// Operator has NOT yet called `POST /v1/internal/pilots/start`.
  /// [User.pilotEndsAt] is null and [User.isDemo] is false.
  notStarted,

  /// The 30-day window has elapsed.
  expired,
}

class PilotStatus {
  const PilotStatus._({required this.code, this.daysRemaining});

  factory PilotStatus.fromUser(User? user) {
    if (user == null) return const PilotStatus._(code: PilotStatusCode.exempt);
    if (user.role == UserRole.admin || user.isDemo) {
      return const PilotStatus._(code: PilotStatusCode.exempt);
    }
    final endsAt = user.pilotEndsAt;
    if (endsAt == null) {
      return const PilotStatus._(code: PilotStatusCode.notStarted);
    }
    final now = DateTime.now();
    if (now.isAfter(endsAt)) {
      return const PilotStatus._(code: PilotStatusCode.expired);
    }
    return PilotStatus._(
      code: PilotStatusCode.active,
      daysRemaining: endsAt.difference(now).inDays,
    );
  }

  final PilotStatusCode code;

  /// Calendar days remaining. Non-null only when [code] == [PilotStatusCode.active].
  final int? daysRemaining;

  bool get isBlocked =>
      code == PilotStatusCode.notStarted || code == PilotStatusCode.expired;
}

/// Derives [PilotStatus] from the current [authProvider] value.
///
/// Re-evaluates whenever the auth state changes (login, logout, cold-start
/// snapshot). Does NOT re-evaluate as wall-clock time passes — the router
/// redirect fires on every navigation, which is sufficient for the MVP.
final pilotStatusProvider = Provider<PilotStatus>((ref) {
  final authState = ref.watch(authProvider);
  final authValue = authState.valueOrNull;
  final user = authValue is AuthAuthenticated ? authValue.user : null;
  return PilotStatus.fromUser(user);
});
