import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import 'auth_provider.dart';

/// Wires [ActivityService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
final activityServiceProvider = Provider<ActivityService>(
  (ref) => ActivityService(ref.read(apiServiceProvider)),
);

/// Online-first list of activities for a single plot, keyed by `plotId`.
///
/// Family-scoped so each plot detail / timeline screen has its own
/// independent state. Mutations re-fetch (online-first; offline persistence
/// is Sprint 4) and replace state immutably.
///
/// Method names are deliberately `createActivity` / `updateActivity` /
/// `deleteActivity` (not `update`/`state`) so they never shadow the
/// `AsyncNotifier` built-ins (`state`, `update`, `future`).
class ActivitiesNotifier extends FamilyAsyncNotifier<List<Activity>, String> {
  // `arg` (the family key) is the plotId. Not cached in a field so a rebuild
  // does not hit a `late final` re-initialisation error.
  String get _plotId => arg;

  @override
  Future<List<Activity>> build(String arg) {
    return ref.read(activityServiceProvider).listByPlot(arg);
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(activityServiceProvider).listByPlot(_plotId),
    );
  }

  Future<void> createActivity({
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    await ref.read(activityServiceProvider).create(
          plotId: _plotId,
          type: type,
          occurredAt: occurredAt,
          description: description,
          photoUrl: photoUrl,
        );
    await _refresh();
  }

  Future<void> updateActivity({
    required String id,
    required ActivityType type,
    required DateTime occurredAt,
    String? description,
    String? photoUrl,
  }) async {
    await ref.read(activityServiceProvider).update(
          id: id,
          plotId: _plotId,
          type: type,
          occurredAt: occurredAt,
          description: description,
          photoUrl: photoUrl,
        );
    await _refresh();
  }

  Future<void> deleteActivity(String id) async {
    await ref.read(activityServiceProvider).delete(id);
    await _refresh();
  }
}

final activitiesProvider =
    AsyncNotifierProvider.family<ActivitiesNotifier, List<Activity>, String>(
  ActivitiesNotifier.new,
);

/// Single activity lookup by id, used by the edit form when deep-linked.
final activityProvider = FutureProvider.family<Activity, String>(
  (ref, id) => ref.read(activityServiceProvider).get(id),
);
