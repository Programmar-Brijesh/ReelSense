import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reelsense/features/commands/screens/voice_commands_screen.dart';
import 'package:reelsense/features/dashboard/screens/dashboard_screen.dart';
import 'package:reelsense/features/dashboard/services/dashboard_preferences_service.dart';
import 'package:reelsense/features/settings/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardPreferencesService Unit Tests', () {
    late DashboardPreferencesService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = DashboardPreferencesService();
    });

    test('Initial defaults load as expected', () async {
      final state = await service.loadControllerState();
      expect(state.isMasterEnabled, isFalse);
      expect(state.isVoiceEnabled, isTrue);
      expect(state.isGestureEnabled, isTrue);
      expect(state.isSessionActive, isFalse);
    });

    test('Master controller ON/OFF persistence', () async {
      await service.setMasterControllerEnabled(true);
      var state = await service.loadControllerState();
      expect(state.isMasterEnabled, isTrue);

      await service.setMasterControllerEnabled(false);
      state = await service.loadControllerState();
      expect(state.isMasterEnabled, isFalse);
    });

    test('Stopping master controller automatically stops active session in persistence', () async {
      await service.setMasterControllerEnabled(true);
      await service.setReelSessionActive(true);
      var state = await service.loadControllerState();
      expect(state.isSessionActive, isTrue);

      await service.setMasterControllerEnabled(false);
      state = await service.loadControllerState();
      expect(state.isMasterEnabled, isFalse);
      expect(state.isSessionActive, isFalse);
    });

    test('Independent Voice and Gesture toggles', () async {
      await service.setVoiceControlEnabled(false);
      var state = await service.loadControllerState();
      expect(state.isVoiceEnabled, isFalse);
      expect(state.isGestureEnabled, isTrue);

      await service.setGestureControlEnabled(false);
      state = await service.loadControllerState();
      expect(state.isVoiceEnabled, isFalse);
      expect(state.isGestureEnabled, isFalse);

      await service.setVoiceControlEnabled(true);
      state = await service.loadControllerState();
      expect(state.isVoiceEnabled, isTrue);
      expect(state.isGestureEnabled, isFalse);
    });
  });

  group('DashboardScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Dashboard renders all core cards and sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to ReelSense'), findsOneWidget);
      expect(find.text('Master Controller'), findsOneWidget);
      expect(find.text('Start Controller'), findsOneWidget);
      expect(find.text('Control Modes'), findsOneWidget);
      expect(find.text('Voice Control'), findsOneWidget);
      expect(find.text('Gesture Control'), findsOneWidget);
      expect(find.text('Reel Session Control'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('My Voice Commands'), findsOneWidget);
      expect(find.text('Gesture Settings'), findsOneWidget);
    });

    testWidgets('Master Controller ON/OFF toggling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      // Initially OFF
      expect(find.text('CONTROLLER OFF'), findsOneWidget);

      // Tap Start Controller
      await tester.tap(find.text('Start Controller'));
      await tester.pumpAndSettle();

      // Now RUNNING
      expect(find.text('CONTROLLER RUNNING'), findsOneWidget);
      expect(find.text('Stop Controller'), findsOneWidget);

      // Tap Stop Controller
      await tester.tap(find.text('Stop Controller'));
      await tester.pumpAndSettle();

      expect(find.text('CONTROLLER OFF'), findsOneWidget);
      expect(find.text('Start Controller'), findsOneWidget);
    });


    testWidgets(
        'Prevent Reel Session from starting if Master Controller is disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      // Master Controller is OFF initially
      expect(find.text('CONTROLLER OFF'), findsOneWidget);

      // Attempt to Start Reel Session
      final sessionButton = find.text('Start Reel Session');
      await tester.ensureVisible(sessionButton);
      await tester.tap(sessionButton);
      await tester.pumpAndSettle();

      // Should show warning SnackBar and remain in STANDBY
      expect(
        find.text(
          'Cannot start Reel Session while Master Controller is disabled.',
        ),
        findsOneWidget,
      );
      expect(find.text('Start Reel Session'), findsOneWidget);
    });

    testWidgets(
        'Reel Session activation and stopping session when Master Controller is disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      // 1. Turn ON Master Controller
      await tester.tap(find.text('Start Controller'));
      await tester.pumpAndSettle();
      expect(find.text('CONTROLLER RUNNING'), findsOneWidget);

      // 2. Start Reel Session
      final startSessionBtn = find.text('Start Reel Session');
      await tester.ensureVisible(startSessionBtn);
      await tester.tap(startSessionBtn);
      await tester.pumpAndSettle();

      // Session is now ACTIVE
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Stop Reel Session'), findsOneWidget);

      // 3. Turn OFF Master Controller -> must automatically stop the active Reel Session
      final stopControllerBtn = find.text('Stop Controller');
      await tester.ensureVisible(stopControllerBtn);
      await tester.tap(stopControllerBtn);
      await tester.pumpAndSettle();

      expect(find.text('CONTROLLER OFF'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('Start Reel Session'), findsOneWidget);
    });

    testWidgets('Independent voice and gesture toggles on Dashboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      // Initially both ON
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // Toggle Voice Switch OFF
      await tester.ensureVisible(switches.at(0));
      await tester.tap(switches.at(0));
      await tester.pumpAndSettle();

      // Toggle Gesture Switch OFF
      await tester.ensureVisible(switches.at(1));
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();

      // Verify persistence
      final service = DashboardPreferencesService();
      final state = await service.loadControllerState();
      expect(state.isVoiceEnabled, isFalse);
      expect(state.isGestureEnabled, isFalse);
    });

    testWidgets('Quick Actions and Settings navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Settings Icon
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Replay Onboarding Flow'), findsOneWidget);

      // Back to Dashboard
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Tap My Voice Commands Quick Action
      final voiceCommandsAction = find.text('My Voice Commands');
      await tester.ensureVisible(voiceCommandsAction);
      await tester.tap(voiceCommandsAction);
      await tester.pumpAndSettle();

      expect(find.byType(VoiceCommandsScreen), findsOneWidget);
      expect(find.text('"Next" / "Scroll Down"'), findsOneWidget);
    });
  });
}
