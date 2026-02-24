import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myna/screens/splash_screen.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('displays quote text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {},
          ),
        ),
      );

      // Allow animations to start; ignore image asset loading errors in test env
      await tester.pump();
      tester.takeException(); // consume any asset-not-found exception

      // Quote should appear (may be opacity 0 initially, but widget exists)
      expect(find.text('آدمی فربه شود از راهِ گوش'), findsOneWidget);
    });

    testWidgets('displays title text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {},
          ),
        ),
      );

      await tester.pump();
      tester.takeException(); // consume any asset-not-found exception

      expect(find.text('پرستو'), findsOneWidget);
    });

    testWidgets('no overflow on small screen (iPhone SE size)',
        (WidgetTester tester) async {
      // iPhone SE screen size: 375 x 667
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {},
          ),
        ),
      );

      await tester.pump();

      // Consume the image asset-not-found exception (asset not registered in test env)
      // and verify no layout overflow errors occurred
      final exception = tester.takeException();
      if (exception != null) {
        // Only asset loading errors are expected, not overflow errors
        expect(exception.toString(), contains('Unable to load asset'));
      }

      // Reset view
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('calls onComplete after animation finishes',
        (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Pump through entire animation (4000ms controller + buffer)
      // Use pump instead of pumpAndSettle to avoid infinite animation loops
      await tester.pump(const Duration(milliseconds: 4500));
      tester.takeException(); // consume any asset-not-found exception

      expect(completed, isTrue);
    });

    testWidgets('has correct text hierarchy', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {},
          ),
        ),
      );

      await tester.pump();
      tester.takeException(); // consume any asset-not-found exception

      // Verify both texts exist in proper hierarchy
      final titleFinder = find.text('پرستو');
      final quoteFinder = find.text('آدمی فربه شود از راهِ گوش');

      expect(titleFinder, findsOneWidget);
      expect(quoteFinder, findsOneWidget);
    });
  });
}
