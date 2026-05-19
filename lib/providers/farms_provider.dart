import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/farm.dart';
import '../services/farm_service.dart';
import 'auth_provider.dart';

/// Wires [FarmService] with the shared [apiServiceProvider] (defined in
/// `auth_provider.dart`) so the Bearer-token interceptor is reused.
final farmServiceProvider = Provider<FarmService>(
  (ref) => FarmService(ref.read(apiServiceProvider)),
);

/// Online-first list of the authenticated producer's farms.
///
/// Sprint 2 is online-first against the API; offline persistence
/// (WatermelonDB) is Sprint 3. Mutations re-fetch from the server rather than
/// patching local state, keeping the source of truth on the backend and the
/// notifier immutable (state is replaced, never mutated in place).
class FarmsNotifier extends AsyncNotifier<List<Farm>> {
  @override
  Future<List<Farm>> build() => ref.read(farmServiceProvider).list();

  Future<void> _refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(farmServiceProvider).list(),
    );
  }

  Future<void> create({
    required String name,
    required String cropType,
    required double areaHectares,
    String? address,
  }) async {
    await ref.read(farmServiceProvider).create(
          name: name,
          cropType: cropType,
          areaHectares: areaHectares,
          address: address,
        );
    await _refresh();
  }

  Future<void> updateFarm({
    required String id,
    required String name,
    required String cropType,
    required double areaHectares,
    String? address,
  }) async {
    await ref.read(farmServiceProvider).update(
          id: id,
          name: name,
          cropType: cropType,
          areaHectares: areaHectares,
          address: address,
        );
    await _refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(farmServiceProvider).delete(id);
    await _refresh();
  }
}

final farmsProvider =
    AsyncNotifierProvider<FarmsNotifier, List<Farm>>(FarmsNotifier.new);

/// Single farm lookup by id, used by the detail screen header. Kept separate
/// from [farmsProvider] so a deep link to a farm detail does not require the
/// full list to have been loaded first.
final farmProvider = FutureProvider.family<Farm, String>(
  (ref, id) => ref.read(farmServiceProvider).get(id),
);
