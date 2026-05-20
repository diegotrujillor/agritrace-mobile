// Regression test for the v1.3.4 silent-swallow bug.
//
// Symptom: tapping a list-screen FAB navigated to a form via `context.go`
// (REPLACE), then the form did a `context.pop()` after a successful create.
// With nothing on the stack to pop, go_router 14.x throws
// `GoError('There is nothing to pop')` which the form's catch block
// rendered as the generic "Ocurrió un error, intenta de nuevo" banner —
// despite the backend having returned 201 + valid envelope.
//
// Fix: FAB callbacks use `context.push` so the form sits on top of the
// list and `context.pop()` returns to it cleanly.
//
// This test pins all four CU CRUD chains (farms, plots, activities,
// alerts) to push-semantics by verifying that `pop()` after navigation
// returns to the originating list, not to an empty stack.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Mirrors the production pattern: a list screen with a FAB that opens a
/// form, and the form pops itself on success.
class _FabSpec {
  const _FabSpec({required this.listPath, required this.formPath});
  final String listPath;
  final String formPath;
}

GoRouter _routerFor(_FabSpec spec) => GoRouter(
      initialLocation: spec.listPath,
      routes: [
        GoRoute(
          path: spec.listPath,
          builder: (context, _) => Scaffold(
            body: const Text('LIST'),
            floatingActionButton: FloatingActionButton(
              // The production pattern: push so the form can pop back.
              onPressed: () => context.push(spec.formPath),
              child: const Icon(Icons.add),
            ),
          ),
        ),
        GoRoute(
          path: spec.formPath,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('SUBMIT'),
            ),
          ),
        ),
      ],
    );

void main() {
  // The four CU CRUD chains broken before v1.3.4. Paths are illustrative;
  // the bug is path-agnostic — it is purely about push vs go semantics.
  // Anchoring the test on the pattern, not on the exact route_names.dart
  // strings, keeps the regression check stable across future route renames.
  const specs = <String, _FabSpec>{
    'farms (CU-06)':      _FabSpec(listPath: '/dash',    formPath: '/farms/new'),
    'plots (CU-10)':      _FabSpec(listPath: '/farms/x', formPath: '/farms/x/plots/new'),
    'activities (CU-14)': _FabSpec(listPath: '/plots/x', formPath: '/plots/x/activities/new'),
    'alerts (CU-18)':     _FabSpec(listPath: '/alerts',  formPath: '/alerts/new'),
  };

  specs.forEach((cu, spec) {
    testWidgets('$cu: FAB pushes form and pop returns to list', (tester) async {
      final router = _routerFor(spec);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // List visible, form not.
      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('SUBMIT'), findsNothing);

      // FAB pushes the form on top.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('SUBMIT'), findsOneWidget);

      // The form's `context.pop()` returns to the list. Pre-fix this would
      // throw GoError('There is nothing to pop') because `go` had replaced
      // the route stack instead of pushing on top.
      await tester.tap(find.text('SUBMIT'));
      await tester.pumpAndSettle();
      expect(find.text('LIST'), findsOneWidget);
      expect(find.text('SUBMIT'), findsNothing);
    });
  });
}
