import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zests_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ZestS End-to-End Tests', () {
    testWidgets('Verify Home Screen and basic navigation rendering',
        (tester) async {
      // Build our app and trigger a frame.
      app.main();
      
      // Wait for the app to settle
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Handle onboarding if present
      final nextFinder = find.text('Next');
      if (nextFinder.evaluate().isNotEmpty) {
        await tester.tap(nextFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      // 1. Verify that the bottom navigation bar is present and has the expected tabs
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('MySchedule'), findsWidgets);
      
      // 2. Since the user is likely not logged in by default, "MyDashboard" 
      // might not be present initially, but we can verify the search tab.
      expect(find.text('Search'), findsWidgets);

      // 3. Verify the Home Tab displays the tip of the day section
      expect(find.text('Tip of the day'), findsOneWidget);
      
      // 4. Verify the new "Compete" text on the banner is present
      // Wait for the banner image to load or fail gracefully
      await tester.pumpAndSettle();
      expect(find.text('Compete'), findsWidgets);

      // 5. Navigate to Search Page
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      
      // Look for search input
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search events'), findsOneWidget);

      // 6. Navigate to Schedule Page
      await tester.tap(find.text('MySchedule').last);
      await tester.pumpAndSettle();

      // Expect to see login required message if guest
      expect(find.text('Login required to view schedule'), findsOneWidget);
      expect(find.text('Login / Sign Up'), findsWidgets);
    });
  });
}
