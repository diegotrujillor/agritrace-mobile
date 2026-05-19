import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/activity.dart';
import '../../navigation/route_names.dart';
import '../../providers/activities_provider.dart';
import '../../providers/plots_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';
import '../../widgets/domain/activity_list_item.dart';

/// Full-screen chronological timeline of a plot's activities (newest first).
/// "Registrar actividad" routes to the activity form.
class ActivityTimelineScreen extends ConsumerWidget {
  const ActivityTimelineScreen({super.key, required this.plotId});

  final String plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plotAsync = ref.watch(plotProvider(plotId));
    final activitiesAsync = ref.watch(activitiesProvider(plotId));

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        title: Text(
          plotAsync.valueOrNull?.name ?? 'Actividades',
          style: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(activitiesProvider(plotId).future),
        child: activitiesAsync.when(
          data: (activities) => activities.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: AppSpacing.xl),
                    _NoActivities(),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: activities.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) => ActivityListItem(
                    activity: _sorted(activities)[index],
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    parseAuthError(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        onPressed: () => context.go(Routes.activityNew(plotId)),
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text(
          'Registrar actividad',
          style: TextStyle(color: AppColors.white),
        ),
      ),
    );
  }
}

/// Newest first. Copies the list before sorting so the provider's immutable
/// state is never mutated in place.
List<Activity> _sorted(List<Activity> activities) {
  final copy = [...activities];
  copy.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return copy;
}

class _NoActivities extends StatelessWidget {
  const _NoActivities();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Text(
          'Este lote aún no tiene actividades registradas',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grey, fontSize: 16),
        ),
      ),
    );
  }
}
