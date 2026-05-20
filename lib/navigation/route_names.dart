abstract final class Routes {
  static const welcome   = '/welcome';
  static const login     = '/login';
  static const register  = '/register';
  static const dashboard = '/dashboard';
  static const farmsNew  = '/farms/new';

  // Alerts (Sprint 4): producer-wide list + reminder form. Static `/new`
  // is declared before the list route in the router, consistent with the
  // farms/plots `/new`-before-`:id` ordering.
  static const alerts    = '/alerts';
  static const alertNew  = '/alerts/new';

  // Parameterised paths registered on the GoRouter. Use the builder helpers
  // below to construct concrete locations rather than string-concatenating
  // at call sites.
  static const farmDetailPath = '/farms/:id';
  static const plotNewPath    = '/farms/:farmId/plots/new';
  static const plotDetailPath = '/plots/:id';
  static const plotEditPath   = '/plots/:id/edit';

  // Activities are scoped to a plot. Static `/new` segment is declared before
  // any `:id` capture in the router so it is never swallowed.
  static const activityNewPath      = '/plots/:plotId/activities/new';
  static const activityTimelinePath = '/plots/:plotId/activities';

  static String farmDetail(String id) => '/farms/$id';
  static String plotNew(String farmId) => '/farms/$farmId/plots/new';
  static String plotDetail(String id) => '/plots/$id';
  static String plotEdit(String id) => '/plots/$id/edit';
  static String activityNew(String plotId) => '/plots/$plotId/activities/new';
  static String activityTimeline(String plotId) =>
      '/plots/$plotId/activities';
}
