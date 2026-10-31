import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reelsense/features/recognition/models/recognition_availability.dart';
import 'package:reelsense/features/recognition/models/recognition_mode.dart';
import 'package:reelsense/features/recognition/services/recognition_availability_service.dart';
import 'package:reelsense/features/recognition/services/recognition_preference_service.dart';
import 'package:reelsense/features/recognition/widgets/initial_recognition_setup_sheet.dart';

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
    statusMessage: 'Not installed',
  );

  group('InitialRecognitionSetupSheet Widget Tests', () {
    testWidgets('Case A: Offline available shows both Offline and Online choices', (tester) async {
      final prefs = RecognitionPreferenceService();
      final availability = FakeAvailabilityService(availability: availableOffline);

      RecognitionMode? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InitialRecognitionSetupSheet(
              locale: 'en-US',
              availabilityService: availability,
              preferenceService: prefs,
              onModeSelected: (mode) {
                selectedResult = mode;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Voice Recognition Setup'), findsOneWidget);
      expect(find.text('Offline Recognition'), findsOneWidget);
      expect(find.text('Online Recognition'), findsOneWidget);

      // Select Offline
      await tester.tap(find.text('Offline Recognition'));
      await tester.pumpAndSettle();

      expect(selectedResult, RecognitionMode.offline);
      final savedMode = await prefs.getSelectedMode();
      expect(savedMode, RecognitionMode.offline);
    });

    testWidgets('Case B: Offline unavailable shows Download Language Pack and Use Online Recognition', (tester) async {
      final prefs = RecognitionPreferenceService();
      final availability = FakeAvailabilityService(availability: unavailableOffline);

      RecognitionMode? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InitialRecognitionSetupSheet(
              locale: 'en-US',
              availabilityService: availability,
              preferenceService: prefs,
              onModeSelected: (mode) {
                selectedResult = mode;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Offline Language Pack Not Available'), findsOneWidget);
      expect(find.text('Download Language Pack'), findsOneWidget);
      expect(find.text('Online Recognition'), findsOneWidget);

      // Select Online
      await tester.tap(find.text('Online Recognition'));
      await tester.pumpAndSettle();

      expect(selectedResult, RecognitionMode.online);
      final savedMode = await prefs.getSelectedMode();
      expect(savedMode, RecognitionMode.online);
    });

    testWidgets('Case B: Tapping Download Language Pack triggers download API', (tester) async {
      final prefs = RecognitionPreferenceService();
      final availability = FakeAvailabilityService(availability: unavailableOffline);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InitialRecognitionSetupSheet(
              locale: 'en-US',
              availabilityService: availability,
              preferenceService: prefs,
              onModeSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Download Language Pack'));
      await tester.pumpAndSettle();

      expect(availability.downloadTriggered, isTrue);
    });
  });
}
