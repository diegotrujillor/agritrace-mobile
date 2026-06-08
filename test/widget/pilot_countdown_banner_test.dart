import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agritrace_mobile/models/user.dart';
import 'package:agritrace_mobile/providers/pilot_status_provider.dart';
import 'package:agritrace_mobile/utils/constants.dart';
import 'package:agritrace_mobile/widgets/common/pilot_countdown_banner.dart';

User _user({
  required DateTime? endsAt,
  bool isDemo = false,
  UserRole role = UserRole.producer,
}) =>
    User(
      id: 'u-1',
      email: 'a@b.com',
      fullName: 'Ana',
      phone: '',
      role: role,
      isDemo: isDemo,
      pilotEndsAt: endsAt,
    );

Future<void> _pump(WidgetTester tester, PilotStatus status) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [pilotStatusProvider.overrideWithValue(status)],
      child: const MaterialApp(
        home: Scaffold(body: PilotCountdownBanner()),
      ),
    ),
  );
}

Container _banner(WidgetTester tester) => tester.widget<Container>(
      find.descendant(
        of: find.byType(PilotCountdownBanner),
        matching: find.byType(Container),
      ),
    );

void main() {
  testWidgets('hidden when more than 5 days remain', (tester) async {
    await _pump(
      tester,
      PilotStatus.fromUser(
        _user(endsAt: DateTime.now().add(const Duration(days: 10))),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.textContaining('piloto'), findsNothing);
  });

  testWidgets('hidden for demo accounts (exempt)', (tester) async {
    await _pump(
      tester,
      PilotStatus.fromUser(
        _user(
          endsAt: DateTime.now().add(const Duration(days: 2)),
          isDemo: true,
        ),
      ),
    );
    expect(find.textContaining('piloto'), findsNothing);
  });

  testWidgets('amber strip + icon when 2–5 days left', (tester) async {
    await _pump(
      tester,
      PilotStatus.fromUser(
        _user(endsAt: DateTime.now().add(const Duration(days: 4, hours: 1))),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('vence en 4 días'), findsOneWidget);
    expect(_banner(tester).color, AppColors.harvestYellow);
  });

  testWidgets('RED strip + "mañana" when 1 day left', (tester) async {
    await _pump(
      tester,
      PilotStatus.fromUser(
        _user(endsAt: DateTime.now().add(const Duration(days: 1, hours: 1))),
      ),
    );
    expect(find.textContaining('mañana'), findsOneWidget);
    expect(_banner(tester).color, AppColors.error);
  });

  testWidgets('RED strip + "hoy" when it expires today (0 days)', (tester) async {
    await _pump(
      tester,
      PilotStatus.fromUser(
        _user(endsAt: DateTime.now().add(const Duration(hours: 1))),
      ),
    );
    expect(find.textContaining('vence hoy'), findsOneWidget);
    expect(_banner(tester).color, AppColors.error);
  });
}
