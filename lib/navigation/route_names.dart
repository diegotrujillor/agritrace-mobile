abstract final class Routes {
  static const welcome   = '/welcome';
  static const login     = '/login';
  static const register  = '/register';
  static const dashboard = '/dashboard';
  static const farmsNew  = '/farms/new';

  // Parameterised paths registered on the GoRouter. Use the builder helpers
  // below to construct concrete locations rather than string-concatenating
  // at call sites.
  static const farmDetailPath = '/farms/:id';
  static const plotNewPath    = '/farms/:farmId/plots/new';
  static const plotDetailPath = '/plots/:id';

  static String farmDetail(String id) => '/farms/$id';
  static String plotNew(String farmId) => '/farms/$farmId/plots/new';
  static String plotDetail(String id) => '/plots/$id';
}
