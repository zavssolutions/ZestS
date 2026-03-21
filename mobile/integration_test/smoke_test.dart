import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

import "package:zests_app/main.dart" as app;

Future<void> _advanceOnboardingIfPresent(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    final next = find.text("Next");
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next);
      continue;
    }
    final cont = find.text("Continue");
    if (cont.evaluate().isNotEmpty) {
      await tester.tap(cont);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }
    return;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Anonymous user can reach Home", (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _advanceOnboardingIfPresent(tester);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.text("ZestS Home"), findsOneWidget);
  });
}
