import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/navigation/route_names.dart';

void main() {
  group('Routes static constants', () {
    const allRoutes = <String>[
      Routes.welcome,
      Routes.login,
      Routes.register,
      Routes.dashboard,
      Routes.farmsNew,
      Routes.alerts,
      Routes.alertNew,
      Routes.farmDetailPath,
      Routes.plotNewPath,
      Routes.plotDetailPath,
      Routes.plotEditPath,
      Routes.activityNewPath,
      Routes.activityTimelinePath,
    ];

    test('all static route constants are non-empty and start with /', () {
      for (final route in allRoutes) {
        expect(route, isNotEmpty);
        expect(route.startsWith('/'), isTrue,
            reason: 'expected $route to start with /');
      }
    });

    test('all static route constants are unique', () {
      expect(allRoutes.toSet().length, allRoutes.length,
          reason: 'duplicate route constants found');
    });
  });

  group('Routes builder helpers', () {
    test('farmDetail interpolates id', () {
      expect(Routes.farmDetail('abc'), '/farms/abc');
    });

    test('plotNew interpolates farmId', () {
      expect(Routes.plotNew('farm-1'), '/farms/farm-1/plots/new');
    });

    test('plotDetail interpolates id', () {
      expect(Routes.plotDetail('plot-9'), '/plots/plot-9');
    });

    test('activityNew interpolates plotId', () {
      expect(Routes.activityNew('p1'), '/plots/p1/activities/new');
    });

    test('activityTimeline interpolates plotId', () {
      expect(Routes.activityTimeline('p1'), '/plots/p1/activities');
    });
  });
}
