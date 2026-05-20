import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/farm.dart';
import '../../navigation/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../providers/farms_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/offline_indicator.dart';
import '../../widgets/domain/farm_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        title: const Text('AgriTrace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.white),
            tooltip: 'Alertas',
            onPressed: () => context.go(Routes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineIndicator(),
          Expanded(
            child: farmsAsync.when(
              data: (farms) => farms.isEmpty
                  ? const EmptyState(
                      icon: Icons.agriculture_outlined,
                      title: 'No tienes fincas aún',
                      subtitle: 'Registra tu primera finca para comenzar',
                      subtitleHeight: 1.5,
                    )
                  : _FarmsList(farms: farms),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: parseApiError(e),
                onRetry: () => ref.invalidate(farmsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        tooltip: 'Registrar finca',
        // push (not go) so the form can `context.pop()` back to dashboard.
        // `go` replaces the stack, leaving nothing to pop and surfacing as
        // a silent GoError after a successful create.
        onPressed: () => context.push(Routes.farmsNew),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }
}

class _FarmsList extends StatelessWidget {
  const _FarmsList({required this.farms});

  final List<Farm> farms;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: farms.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final farm = farms[index];
        return FarmCard(
          farm: farm,
          onTap: () => context.go(Routes.farmDetail(farm.id)),
        );
      },
    );
  }
}

