import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reelsense/features/dashboard/screens/dashboard_screen.dart';
import 'package:reelsense/features/onboarding/screens/onboarding_screen.dart';
import 'package:reelsense/features/onboarding/services/onboarding_storage_service.dart';
import 'package:reelsense/features/splash/screens/splash_screen.dart';
import 'package:reelsense/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('First launch: SplashScreen transitions to OnboardingScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // Fast forward splash animation (3000ms + route transition 600ms)
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Your Reels, Your Control.'), findsOneWidget);
  });

  testWidgets('Onboarding: Skip marks completion and navigates to Dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    // Tap Skip button
    final skipButton = find.text('Skip').first;
    expect(skipButton, findsOneWidget);
    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    // Verify Dashboard is displayed
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Verify storage has been updated
    final completed = await OnboardingStorageService().hasCompletedOnboarding();
    expect(completed, isTrue);
  });

  testWidgets('Onboarding: Step through 3 pages and tap Get Started',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    // Page 1
    expect(find.text('Your Reels, Your Control.'), findsOneWidget);
    expect(find.text('Hands-free scrolling'), findsOneWidget);

    // Tap Next to go to Page 2
    final nextButton = find.byIcon(Icons.arrow_forward_rounded);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Page 2
    expect(find.text('Speak It. Gesture It. Control It.'), findsOneWidget);
    expect(find.text('Add custom voice commands'), findsOneWidget);

    // Tap Next to go to Page 3
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Page 3
    expect(find.text('Your Device. Your Control.'), findsOneWidget);
    expect(find.text('No account registration required'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap Get Started
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify Dashboard is displayed
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Verify storage has completed onboarding
    final completed = await OnboardingStorageService().hasCompletedOnboarding();
    expect(completed, isTrue);
  });

  testWidgets('Subsequent launch: SplashScreen transitions directly to Dashboard',
      (WidgetTester tester) async {
    // Set already completed
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
    });

    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pumpAndSettle();

    // Expect DashboardScreen directly, bypassing OnboardingScreen
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
