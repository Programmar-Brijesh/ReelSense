import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reelsense/features/recognition/models/recognition_availability.dart';
import 'package:reelsense/features/recognition/models/recognition_mode.dart';
import 'package:reelsense/features/recognition/screens/voice_settings_screen.dart';
import 'package:reelsense/features/recognition/services/recognition_availability_service.dart';
import 'package:reelsense/features/recognition/services/recognition_preference_service.dart';

class FakeAvailabilityService extends RecognitionAvailabilityService {
  RecognitionAvailability availability;
  bool downloadTriggered = false;

  FakeAvailabilityService({required this.availability});

  @override
  Future<RecognitionAvailability> checkAvailability(String locale) async {
    return availability;
  }

  @override
  Future<bool> triggerModelDownload(String locale) async {
    downloadTriggered = true;
    return true;
  }

  @override
  Future<bool> openVoiceSettings() async {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const availableOffline = RecognitionAvailability(
    isRecognitionAvailable: true,
    isOnDeviceAvailable: true,
    isOfflineLocaleInstalled: true,
    isOfflineLocaleSupported: true,
    isOnlineAvailable: true,
    installedOfflineLanguages: ['en-US'],
    androidApiVersion: 34,
    statusMessage: 'Available',
  );

  const unavailableOffline = RecognitionAvailability(
    isRecognitionAvailable: true,
    isOnDeviceAvailable: true,
    isOfflineLocaleInstalled: false,
    isOfflineLocaleSupported: true,
    isOnlineAvailable: true,
    installedOfflineLanguages: [],
    androidApiVersion: 34,
    statusMessage: 'Pack not installed',
  );

  group('VoiceSettingsScreen Widget Tests', () {
    testWidgets('Renders all speech recognition mode cards and info', (tester) async {
      final prefs = RecognitionPreferenceService();
      await prefs.setSelectedMode(RecognitionMode.online);

      final availability = FakeAvailabilityService(availability: availableOffline);

      await tester.pumpWidget(
        MaterialApp(
          home: VoiceSettingsScreen(
            preferenceService: prefs,
            availabilityService: availability,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Speech Recognition Mode'), findsWidgets);
      expect(find.text('Offline Recognition'), findsOneWidget);
      expect(find.text('Online Recognition'), findsWidgets); // In banner and in card
      expect(find.text('Recognition Language'), findsOneWidget);
    });

    testWidgets('Switching Online -> Offline when available updates preference to Offline', (tester) async {
      final prefs = RecognitionPreferenceService();
      await prefs.setSelectedMode(RecognitionMode.online);

      final availability = FakeAvailabilityService(availability: availableOffline);

      await tester.pumpWidget(
        MaterialApp(
          home: VoiceSettingsScreen(
            preferenceService: prefs,
            availabilityService: availability,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Offline Recognition card
      await tester.tap(find.text('Offline Recognition'));
      await tester.pumpAndSettle();

      final updatedMode = await prefs.getSelectedMode();
      expect(updatedMode, RecognitionMode.offline);
    });

    testWidgets('Switching Online -> Offline when pack missing prompts download and keeps Online preference', (tester) async {
      final prefs = RecognitionPreferenceService();
      await prefs.setSelectedMode(RecognitionMode.online);

      final availability = FakeAvailabilityService(availability: unavailableOffline);

      await tester.pumpWidget(
        MaterialApp(
          home: VoiceSettingsScreen(
            preferenceService: prefs,
            availabilityService: availability,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Offline Recognition card
      await tester.tap(find.text('Offline Recognition'));
      await tester.pumpAndSettle();

      // Download prompt dialog should appear
      expect(find.text('Offline Pack Not Available'), findsOneWidget);
      expect(find.text('Download Language Pack'), findsWidgets);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Preference must remain unchanged as Online
      final currentMode = await prefs.getSelectedMode();
      expect(currentMode, RecognitionMode.online);
    });

    testWidgets('Switching Offline -> Online updates preference to Online', (tester) async {
      final prefs = RecognitionPreferenceService();
      await prefs.setSelectedMode(RecognitionMode.offline);

      final availability = FakeAvailabilityService(availability: availableOffline);

      await tester.pumpWidget(
        MaterialApp(
          home: VoiceSettingsScreen(
            preferenceService: prefs,
            availabilityService: availability,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Online Recognition card (it's the card when offline is in banner)
      await tester.tap(find.text('Online Recognition'));
      await tester.pumpAndSettle();

      final updatedMode = await prefs.getSelectedMode();
      expect(updatedMode, RecognitionMode.online);
    });
  });
}
