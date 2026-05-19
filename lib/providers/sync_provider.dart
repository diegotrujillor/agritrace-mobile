import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

/// Wires [SyncService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.read(apiServiceProvider)),
);

/// Sync state.
///
/// `null` data means "never synced this session". [SyncNotifier.trigger]
/// runs a push+pull round trip and stores the [SyncResult]; the timestamp of
/// the last successful sync becomes the `since` cursor for the next run.
///
/// Method name is `trigger` (not `update`/`state`) so it does not shadow the
/// `AsyncNotifier` built-ins.
class SyncNotifier extends AsyncNotifier<SyncResult?> {
  DateTime? _lastSyncedAt;

  @override
  Future<SyncResult?> build() async => null;

  Future<void> trigger({List<SyncChange> changes = const []}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(syncServiceProvider).syncNow(
            changes: changes,
            since: _lastSyncedAt,
          );
      _lastSyncedAt = result.timestamp;
      return result;
    });
  }
}

final syncProvider =
    AsyncNotifierProvider<SyncNotifier, SyncResult?>(SyncNotifier.new);
