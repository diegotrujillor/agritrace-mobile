import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plot.dart';
import '../repositories/plot_repository.dart';
import '../services/plot_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Wires [PlotService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
///
/// Still used for individual [plotProvider] lookups and as a fallback seed
/// when the local DB has no plots for the given farm.
final plotServiceProvider = Provider<PlotService>(
  (ref) => PlotService(ref.read(apiServiceProvider)),
);

/// Offline-first list of plots for a single farm, keyed by `farmId`.
///
/// Family-scoped so each farm detail screen has its own independent state.
/// Mutations write to SQLite first and re-read from the local DB.
class PlotsNotifier extends FamilyAsyncNotifier<List<Plot>, String> {
  // `arg` (the family key) is the farmId.
  String get _farmId => arg;
  PlotRepository get _repo => ref.read(plotRepositoryProvider);

  @override
  Future<List<Plot>> build(String arg) async {
    // Seed local DB if no plots for this farm (first login or fresh install).
    final repo = _repo;
    final local = await repo.listByFarm(_farmId);
    if (local.isEmpty) {
      try {
        final remote =
            await ref.read(plotServiceProvider).listByFarm(_farmId);
        for (final plot in remote) {
          await repo.upsertFromServer({
            ...plot.toJson(),
            'updatedAt': plot.createdAt.toIso8601String(),
          });
        }
      } catch (_) {
        // Network unavailable — continue with empty local DB.
      }
    }

    // Subscribe to reactive DB stream for this farm.
    ref.listen<AsyncValue<List<Plot>>>(
      _plotsStreamProvider(_farmId),
      (_, next) => state = next,
    );

    return _repo.listByFarm(_farmId);
  }

  Future<void> create({
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.create(
        farmId: _farmId,
        name: name,
        cropType: cropType,
        status: status,
        variety: variety,
        areaHectares: areaHectares,
      );
      return _repo.listByFarm(_farmId);
    });
  }

  Future<void> updatePlot({
    required String id,
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final existing =
          (await _repo.listByFarm(_farmId)).firstWhere((p) => p.id == id);
      await _repo.update(
        existing,
        name: name,
        cropType: cropType,
        status: status,
        variety: variety,
        areaHectares: areaHectares,
      );
      return _repo.listByFarm(_farmId);
    });
  }

  Future<void> deletePlot(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.delete(id);
      return _repo.listByFarm(_farmId);
    });
  }
}

final plotsProvider =
    AsyncNotifierProvider.family<PlotsNotifier, List<Plot>, String>(
  PlotsNotifier.new,
);

/// Internal stream provider keyed by farmId for reactive DB updates.
final _plotsStreamProvider = StreamProvider.family<List<Plot>, String>(
  (ref, farmId) =>
      ref.watch(plotRepositoryProvider).watchByFarm(farmId),
);

/// Single plot lookup by id, used by the plot detail screen.
///
/// v1.9.0 — bug #20 fix. Local-first lookup: a freshly-created plot
/// lives in pending-sync state for up to 14 days, so a server hit on
/// the detail screen returned "No tienes permiso" (the backend didn't
/// know it yet) and the interceptor occasionally interpreted that as a
/// session-collapse and bounced the user to /welcome. Reading from
/// SQLite first sidesteps both failure modes.
final plotProvider = FutureProvider.family<Plot, String>((ref, id) async {
  final local = await ref.read(plotRepositoryProvider).getById(id);
  if (local != null) return local;
  return ref.read(plotServiceProvider).get(id);
});
