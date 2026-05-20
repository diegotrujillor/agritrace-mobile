import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert.dart';
import '../services/alert_service.dart';
import 'auth_provider.dart';

/// Wires [AlertService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
final alertServiceProvider = Provider<AlertService>(
  (ref) => AlertService(ref.read(apiServiceProvider)),
);

/// Online-first list of the producer's alerts (weather + reminders).
///
/// Mutations re-fetch (online-first; offline persistence is a later
/// release) and replace state immutably. Method names are
/// `createReminder` / `dismiss` / `deleteAlert` / `runWeatherCheck` so
/// they never shadow the `AsyncNotifier` built-ins.
class AlertsNotifier extends AsyncNotifier<List<Alert>> {
  @override
  Future<List<Alert>> build() {
    return ref.read(alertServiceProvider).list();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(alertServiceProvider).list(),
    );
  }

  Future<void> createReminder({
    required String title,
    required DateTime scheduledFor,
    String? body,
    String? plotId,
  }) async {
    await ref.read(alertServiceProvider).createReminder(
          title: title,
          scheduledFor: scheduledFor,
          body: body,
          plotId: plotId,
        );
    await _refresh();
  }

  Future<void> dismiss(String id) async {
    await ref
        .read(alertServiceProvider)
        .update(id, status: AlertStatus.dismissed);
    await _refresh();
  }

  Future<void> deleteAlert(String id) async {
    await ref.read(alertServiceProvider).delete(id);
    await _refresh();
  }

  /// Runs the server weather check for [plotId]; refreshes the list so a
  /// newly raised weather alert shows up. Returns the provider name so the
  /// UI can tell the user when weather is disabled server-side.
  Future<String> runWeatherCheck(String plotId) async {
    final result = await ref.read(alertServiceProvider).checkWeather(plotId);
    await _refresh();
    return result.provider;
  }

  /// Runs the server weather check for every plot in [plotIds] and refreshes
  /// the list once at the end (a single refresh, not one per plot). Returns
  /// the count of new weather alerts the provider actually raised — i.e.
  /// responses where `alert != null`. Used by the manual "Actualizar clima"
  /// trigger on the alerts screen (CU-19).
  Future<int> runWeatherCheckForAllPlots(List<String> plotIds) async {
    final service = ref.read(alertServiceProvider);
    var newAlerts = 0;
    for (final plotId in plotIds) {
      final result = await service.checkWeather(plotId);
      if (result.alert != null) newAlerts++;
    }
    await _refresh();
    return newAlerts;
  }
}

final alertsProvider =
    AsyncNotifierProvider<AlertsNotifier, List<Alert>>(AlertsNotifier.new);
