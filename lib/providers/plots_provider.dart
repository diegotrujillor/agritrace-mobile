import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plot.dart';
import '../services/plot_service.dart';
import 'auth_provider.dart';

/// Wires [PlotService] with the shared [apiServiceProvider] so the
/// Bearer-token interceptor is reused.
final plotServiceProvider = Provider<PlotService>(
  (ref) => PlotService(ref.read(apiServiceProvider)),
);

/// Online-first list of plots for a single farm, keyed by `farmId`.
///
/// Family-scoped so each farm detail screen has its own independent state and
/// disposes when the screen is gone. Mutations re-fetch (online-first; offline
/// sync is Sprint 3) and replace state immutably.
class PlotsNotifier extends FamilyAsyncNotifier<List<Plot>, String> {
  // `arg` (the family key) is the farmId. It is not cached in a field so a
  // rebuild does not hit a `late final` re-initialisation error.
  String get _farmId => arg;

  @override
  Future<List<Plot>> build(String arg) {
    return ref.read(plotServiceProvider).listByFarm(arg);
  }

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(plotServiceProvider).listByFarm(_farmId),
    );
  }

  Future<void> create({
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    await ref.read(plotServiceProvider).create(
          farmId: _farmId,
          name: name,
          cropType: cropType,
          status: status,
          variety: variety,
          areaHectares: areaHectares,
        );
    await _refresh();
  }

  Future<void> updatePlot({
    required String id,
    required String name,
    required String cropType,
    required PlotStatus status,
    String? variety,
    double? areaHectares,
  }) async {
    await ref.read(plotServiceProvider).update(
          id: id,
          farmId: _farmId,
          name: name,
          cropType: cropType,
          status: status,
          variety: variety,
          areaHectares: areaHectares,
        );
    await _refresh();
  }
}

final plotsProvider =
    AsyncNotifierProvider.family<PlotsNotifier, List<Plot>, String>(
  PlotsNotifier.new,
);

/// Single plot lookup by id, used by the plot detail screen.
final plotProvider = FutureProvider.family<Plot, String>(
  (ref, id) => ref.read(plotServiceProvider).get(id),
);
