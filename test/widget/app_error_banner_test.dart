import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agritrace_mobile/widgets/common/app_error_banner.dart';

void main() {
  group('AppErrorBanner', () {
    testWidgets('renders the message when non-null', (tester) async {
      const message = 'Credenciales incorrectas';

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppErrorBanner(message: message)),
      ));

      expect(find.text(message), findsOneWidget);
    });

    testWidgets('renders an empty SizedBox when message is null',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppErrorBanner(message: null)),
      ));

      expect(find.byType(Container), findsNothing);
      // SizedBox.shrink() is rendered when message is null.
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders a Container with text when message is non-empty',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AppErrorBanner(message: 'Algo salió mal')),
      ));

      expect(find.byType(Container), findsOneWidget);
      expect(find.text('Algo salió mal'), findsOneWidget);
    });
  });
}
