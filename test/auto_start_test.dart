import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reelsense/features/autostart/models/auto_start_config.dart';
import 'package:reelsense/features/autostart/screens/auto_start_settings_screen.dart';
import 'package:reelsense/features/autostart/services/auto_start_platform_service.dart';
import 'package:reelsense/features/autostart/services/auto_start_preference_service.dart';
import 'package:reelsense/features/autostart/widgets/auto_start_setup_sheet.dart';
import 'package:reelsense/features/recognition/models/recognition_availability.dart';
import 'package:reelsense/features/recognition/models/recognition_mode.dart';
import 'package:reelsense/features/recognition/services/recognition_availability_service.dart';

class FakeAutoStartPlatformService extends AutoStartPlatformService {
  bool isA11yEnabled;
  bool isOverlayGranted;
  bool isServiceRunning;
  bool startServiceSuccess;

  FakeAutoStartPlatformService({
    this.isA11yEnabled = false,
    this.isOverlayGranted = false,
    this.isServiceRunning = false,
    this.startServiceSuccess = true,
  });

  @override
  Future<bool> isAccessibilityServiceEnabled() async => isA11yEnabled;

  @override
  Future<bool> openAccessibilitySettings() async => true;

  @override
  Future<bool> isOverlayPermissionGranted() async => isOverlayGranted;

  @override
  Future<bool> requestOverlayPermission() async => true;

  @override
  Future<bool> isMonitoringServiceRunning() async => isServiceRunning;

  @override
  Future<bool> startMonitoringService(AutoStartConfig config) async {
    if (startServiceSuccess) {
      isServiceRunning = true;
      return true;
    }
    return false;
  }

  @override
  Future<bool> stopMonitoringService() async {
    isServiceRunning = false;
    return true;
  }

  @override
  Future<bool> updateConfig(AutoStartConfig config) async => true;

  @override
  Future<AutoStartServiceStatus> getServiceStatus() async {
    return AutoStartServiceStatus(
      isMonitoringRunning: isServiceRunning,
      isAccessibilityEnabled: isA11yEnabled,
      isOverlayGranted: isOverlayGranted,
      hasAccessibilityInstance: isA11yEnabled,
    );
  }
}

class FakeAvailabilityService extends RecognitionAvailabilityService {
  final RecognitionAvailability availability;
  bool audioPermission;

  FakeAvailabilityService({
    required this.availability,
    this.audioPermission = true,
  });

  @override
  Future<RecognitionAvailability> checkAvailability(String locale) async {
    return availability;
  }

  @override
  Future<bool> hasRecordAudioPermission() async => audioPermission;

  @override
  Future<bool> requestRecordAudioPermission() async {
    audioPermission = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AutoStartPreferenceService Unit Tests', () {
    test('Auto-Start is OFF by default', () async {
      final prefs = AutoStartPreferenceService();
      final isEnabled = await prefs.isEnabled();
      expect(isEnabled, isFalse);

      final config = await prefs.loadConfig();
      expect(config.isEnabled, isFalse);
      expect(config.controllerMode, AutoStartControllerMode.voice);
      expect(config.hasCompletedSetup, isFalse);
    });

    test('Persists user explicit consent and mode selection', () async {
      final prefs = AutoStartPreferenceService();
      await prefs.setEnabled(true);
      await prefs.setControllerMode(AutoStartControllerMode.gesture);
      await prefs.setSetupCompleted(true);

      var config = await prefs.loadConfig();
      expect(config.isEnabled, isTrue);
      expect(config.controllerMode, AutoStartControllerMode.gesture);
      expect(config.hasCompletedSetup, isTrue);

      // Change mode to voice
      await prefs.setControllerMode(AutoStartControllerMode.voice);
      config = await prefs.loadConfig();
      expect(config.controllerMode, AutoStartControllerMode.voice);
    });

    test('Full configuration load and save preserves all attributes', () async {
      final prefs = AutoStartPreferenceService();
      const customConfig = AutoStartConfig(
        isEnabled: true,
        controllerMode: AutoStartControllerMode.voice,
        recognitionMode: RecognitionMode.online,
        locale: 'hi-IN',
        hasCompletedSetup: true,
        updatedAt: 123456789,
      );

      await prefs.saveConfig(customConfig);

      // Simulate app restart with a fresh service instance
      final restartedPrefs = AutoStartPreferenceService();
      final loaded = await restartedPrefs.loadConfig();

      expect(loaded.isEnabled, isTrue);
      expect(loaded.controllerMode, AutoStartControllerMode.voice);
      expect(loaded.recognitionMode, RecognitionMode.online);
      expect(loaded.locale, 'hi-IN');
      expect(loaded.hasCompletedSetup, isTrue);
    });
  });

  group('AutoStartSettingsScreen Widget Tests', () {
    testWidgets('Renders all core cards, switch, and live status', (tester) async {
      final prefs = AutoStartPreferenceService();
      final platform = FakeAutoStartPlatformService(
        isA11yEnabled: true,
        isOverlayGranted: true,
        isServiceRunning: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AutoStartSettingsScreen(
            platformService: platform,
            preferenceService: prefs,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Auto-Start Controller'), findsWidgets);
      expect(find.text('Controller Mode on Instagram'), findsOneWidget);
      expect(find.text('Live Diagnostic Status'), findsOneWidget);
      expect(find.text('Accessibility Service'), findsWidgets);
      expect(find.text('Floating Overlay Window'), findsOneWidget);
    });

    testWidgets('Toggling controller mode updates configuration', (tester) async {
      final prefs = AutoStartPreferenceService();
      final platform = FakeAutoStartPlatformService();

      await tester.pumpWidget(
        MaterialApp(
          home: AutoStartSettingsScreen(
            platformService: platform,
            preferenceService: prefs,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Gesture Control card
      await tester.tap(find.text('Gesture Control'));
      await tester.pumpAndSettle();

      final config = await prefs.loadConfig();
      expect(config.controllerMode, AutoStartControllerMode.gesture);
    });
  });

  group('AutoStartSetupSheet Widget Tests', () {
    const readyAvail = RecognitionAvailability(
      isRecognitionAvailable: true,
      isOnDeviceAvailable: true,
      isOfflineLocaleInstalled: true,
      isOfflineLocaleSupported: true,
      isOnlineAvailable: true,
      installedOfflineLanguages: ['en-US'],
      androidApiVersion: 34,
      statusMessage: 'Ready',
    );

    testWidgets('Shows complete checklist and enables Start button when prerequisites met', (tester) async {
      final prefs = AutoStartPreferenceService();
      final platform = FakeAutoStartPlatformService(
        isA11yEnabled: true,
        isOverlayGranted: true,
      );
      final availService = FakeAvailabilityService(
        availability: readyAvail,
        audioPermission: true,
      );

      bool setupCompletedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutoStartSetupSheet(
              platformService: platform,
              preferenceService: prefs,
              availabilityService: availService,
              onSetupCompleted: (ok) {
                setupCompletedCalled = ok;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Auto-Start Setup'), findsOneWidget);
      expect(find.text('1. Select Controller Mode'), findsOneWidget);
      expect(find.text('2. Verify Required Capabilities'), findsOneWidget);

      final startButton = find.text('Start & Enable Auto-Start');
      expect(startButton, findsOneWidget);

      // Scroll button into view and tap
      await tester.ensureVisible(startButton);
      await tester.pumpAndSettle();
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(setupCompletedCalled, isTrue);
      final isEnabled = await prefs.isEnabled();
      expect(isEnabled, isTrue);
      expect(platform.isServiceRunning, isTrue);
    });

    testWidgets('Disallows start when accessibility service is not enabled', (tester) async {
      final prefs = AutoStartPreferenceService();
      final platform = FakeAutoStartPlatformService(
        isA11yEnabled: false, // Not enabled
        isOverlayGranted: true,
      );
      final availService = FakeAvailabilityService(
        availability: readyAvail,
        audioPermission: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutoStartSetupSheet(
              platformService: platform,
              preferenceService: prefs,
              availabilityService: availService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final disabledButton = find.text('Complete Requirements Above');
      expect(disabledButton, findsOneWidget);

      // Scroll into view and tap
      await tester.ensureVisible(disabledButton);
      await tester.pumpAndSettle();
      await tester.tap(disabledButton);
      await tester.pumpAndSettle();

      expect(find.text('Please complete all required permissions above before enabling Auto-Start.'), findsOneWidget);
      final isEnabled = await prefs.isEnabled();
      expect(isEnabled, isFalse);
    });
  });
}
