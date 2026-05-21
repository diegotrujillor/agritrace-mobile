import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/farm.dart';
import '../repositories/farm_repository.dart';
import '../services/farm_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

/// Wires [FarmService] with the shared [apiServiceProvider] (defined in
/// `auth_provider.dart`) so the Bearer-token interceptor is reused.
///
/// Still used for individual [farmProvider] lookups and as a fallback seed
/// when the local DB is empty.
final farmServiceProvider = Provider<FarmService>(
  (ref) => FarmService(ref.read(apiServiceProvider)),
);

/// Offline-first list of the authenticated producer's farms.
///
/// [build] subscribes to the reactive SQLite stream via [FarmRepository].
/// The stream emits immediately from local data (no network round-trip
/// needed) and re-emits whenever the DB changes. Mutations write to SQLite
/// first.
class FarmsNotifier extends AsyncNotifier<List<Farm>> {
  FarmRepository get _repo => ref.read(farmRepositoryProvider);

  @override
  Future<List<Farm>> build() async {
    // Seed local DB if empty (first login or fresh install).
    final repo = _repo;
    final local = await repo.listAll();
    if (local.isEmpty) {
      try {
        final remote = await ref.read(farmServiceProvider).list();
        for (final farm in remote) {
          await repo.upsertFromServer({
            ...farm.toJson(),
            'updatedAt': farm.createdAt.toIso8601String(),
          });
        }
      } catch (_) {
        // Network unavailable — continue with empty local DB.
      }
    }

    // Subscribe to the reactive DB stream; every emission replaces state.
    ref.listen<AsyncValue<List<Farm>>>(
      _farmsStreamProvider,
      (_, next) => state = next,
    );

    return _repo.listAll();
  }

  Future<void> create({
    required String name,
    required String cropType,
    required double areaHectares,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.create(
        name: name,
        cropType: cropType,
        areaHectares: areaHectares,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
      return _repo.listAll();
    });
  }

  Future<void> updateFarm({
    required String id,
    required String name,
    required String cropType,
    required double areaHectares,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final existing = (await _repo.listAll()).firstWhere((f) => f.id == id);
      await _repo.update(
        existing,
        name: name,
        cropType: cropType,
        areaHectares: areaHectares,
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
      return _repo.listAll();
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.delete(id);
      return _repo.listAll();
    });
  }
}

final farmsProvider =
    AsyncNotifierProvider<FarmsNotifier, List<Farm>>(FarmsNotifier.new);

/// Internal stream provider used by [FarmsNotifier] to react to DB changes.
final _farmsStreamProvider = StreamProvider<List<Farm>>(
  (ref) => ref.watch(farmRepositoryProvider).watchAll(),
);

/// Single farm lookup by id, used by the detail screen header. Kept separate
/// from [farmsProvider] so a deep link to a farm detail does not require the
/// full list to have been loaded first.
final farmProvider = FutureProvider.family<Farm, String>(
  (ref, id) => ref.read(farmServiceProvider).get(id),
);
