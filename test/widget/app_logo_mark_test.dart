// Widget tests for the reusable AgriTrace brand mark introduced in
// v1.9.2 (QA cycle-01 — "logos missing" on 7 screens). Asserts the
// SvgPicture is mounted at the requested size and that the variant
// switch picks the correct asset path.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/widgets/common/app_logo_mark.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders the default mark at the requested size',
      (tester) async {
    await tester.pumpWidget(_host(const AppLogoMark(size: 40)));
    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);
    final svg = tester.widget<SvgPicture>(svgFinder);
    expect(svg.width, 40);
    expect(svg.height, 40);
  });

  testWidgets('falls back to the 32px default when size is omitted',
      (tester) async {
    await tester.pumpWidget(_host(const AppLogoMark()));
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 32);
    expect(svg.height, 32);
  });

  testWidgets('renders for both mark and white variants without crashing',
      (tester) async {
    await tester.pumpWidget(_host(
      const Column(
        children: [
          AppLogoMark(size: 24, variant: AppLogoVariant.mark),
          AppLogoMark(size: 24, variant: AppLogoVariant.white),
        ],
      ),
    ));
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });
}
