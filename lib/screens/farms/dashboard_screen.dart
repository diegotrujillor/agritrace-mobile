import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/farm.dart';
import '../../navigation/route_names.dart';
import '../../providers/auth_provider.dart';
import '../../providers/farms_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
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
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          'AgriTrace',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
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
                  ? const _EmptyState()
                  : _FarmsList(farms: farms),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: parseAuthError(e),
                onRetry: () => ref.invalidate(farmsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        tooltip: 'Registrar finca',
        onPressed: () => context.go(Routes.farmsNew),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.agriculture_outlined,
              size: 80,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No tienes fincas aún',
              style: GoogleFonts.inter(
                color: AppColors.darkGreen,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Registra tu primera finca para comenzar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
