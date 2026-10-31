import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:reelsense/features/commands/data/command_database_helper.dart';
import 'package:reelsense/features/commands/data/voice_command_repository.dart';
import 'package:reelsense/features/commands/models/reel_action.dart';
import 'package:reelsense/features/commands/services/voice_command_service.dart';
import 'package:reelsense/features/recognition/models/recognition_mode.dart';
import 'package:reelsense/features/recognition/models/recognition_state.dart';
import 'package:reelsense/features/recognition/services/android_speech_recognition_handler.dart';
import 'package:reelsense/features/recognition/services/recognition_availability_service.dart';
import 'package:reelsense/features/recognition/services/recognition_preference_service.dart';
import 'package:reelsense/features/recognition/services/speech_recognition_service.dart';
import 'package:reelsense/features/recognition/services/voice_command_matcher.dart';

class MockAndroidSpeechRecognitionHandler implements AndroidSpeechRecognitionHandler {
  bool hasPermission = true;
  bool isRecognitionAvail = true;
  bool isOnDeviceAvail = true;
  bool isOfflineInstalled = true;
  bool isOfflineSupported = true;
  bool isOnlineAvail = true;
  List<String> installedLanguages = ['en-US', 'hi-IN'];
  int apiVersion = 33;

  bool triggerDownloadCalled = false;
  bool openSettingsCalled = false;
  String? lastStartedMode;
  String? lastStartedLocale;

  @override
  Future<bool> hasRecordAudioPermission() async => hasPermission;

  @override
  Future<bool> requestRecordAudioPermission() async => hasPermission;

  @override
  Future<Map<dynamic, dynamic>> checkAvailability(String locale) async {
    return {
      'isRecognitionAvailable': isRecognitionAvail,
      'isOnDeviceAvailable': isOnDeviceAvail,
      'isOfflineLocaleInstalled': isOfflineInstalled,
      'isOfflineLocaleSupported': isOfflineSupported,
      'isOnlineAvailable': isOnlineAvail,
      'installedOfflineLanguages': installedLanguages,
      'androidApiVersion': apiVersion,
      'statusMessage': isOfflineInstalled ? 'Pack installed' : 'Not installed',
    };
  }

  @override
  Future<bool> triggerModelDownload(String locale) async {
    triggerDownloadCalled = true;
    return true;
  }

  @override
  Future<bool> openVoiceSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<bool> startListening({required String mode, required String locale}) async {
    lastStartedMode = mode;
    lastStartedLocale = locale;
    return true;
  }

  @override
  Future<bool> stopListening() async => true;

  @override
  Future<bool> cancelListening() async => true;

  @override
  Stream<Map<dynamic, dynamic>> get eventStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('RecognitionPreferenceService Unit Tests', () {
    late RecognitionPreferenceService prefs;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      prefs = RecognitionPreferenceService();
    });

    test('Initial preferences: null mode, default locale, setup not completed', () async {
      final mode = await prefs.getSelectedMode();
      final locale = await prefs.getSelectedLocale();
      final isDone = await prefs.isInitialSetupDone();

      expect(mode, isNull);
      expect(locale, 'en-US');
      expect(isDone, isFalse);
    });

    test('Saving Offline mode permanently persists preference and timestamp', () async {
      await prefs.setSelectedMode(RecognitionMode.offline);

      expect(await prefs.getSelectedMode(), RecognitionMode.offline);
      expect(await prefs.isInitialSetupDone(), isTrue);
      expect(await prefs.getPreferenceUpdatedAt(), isNotNull);
    });

    test('Saving Online mode permanently persists preference', () async {
      await prefs.setSelectedMode(RecognitionMode.online);

      expect(await prefs.getSelectedMode(), RecognitionMode.online);
      expect(await prefs.isInitialSetupDone(), isTrue);
    });

    test('Simulating app restart restores previously saved preference', () async {
      await prefs.setSelectedMode(RecognitionMode.offline);
      await prefs.setSelectedLocale('hi-IN');

      // Create new service instance reading from same persisted storage
      final restoredPrefs = RecognitionPreferenceService();
      expect(await restoredPrefs.getSelectedMode(), RecognitionMode.offline);
      expect(await restoredPrefs.getSelectedLocale(), 'hi-IN');
      expect(await restoredPrefs.isInitialSetupDone(), isTrue);
    });

    test('Switching Offline to Online updates preference permanently', () async {
      await prefs.setSelectedMode(RecognitionMode.offline);
      expect(await prefs.getSelectedMode(), RecognitionMode.offline);

      await prefs.setSelectedMode(RecognitionMode.online);
      expect(await prefs.getSelectedMode(), RecognitionMode.online);
    });
  });

  group('SpeechRecognitionService Lifecycle & Mode Switching Logic', () {
    late MockAndroidSpeechRecognitionHandler mockHandler;
    late RecognitionPreferenceService prefs;
    late RecognitionAvailabilityService availService;
    late SpeechRecognitionService speechService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockHandler = MockAndroidSpeechRecognitionHandler();
      prefs = RecognitionPreferenceService();
      availService = RecognitionAvailabilityService(handler: mockHandler);
      speechService = SpeechRecognitionService(
        prefs: prefs,
        availabilityService: availService,
        handler: mockHandler,
      );
    });

    test('Online -> Offline switch succeeds when offline pack is available', () async {
      mockHandler.isOfflineInstalled = true;
      mockHandler.isOnDeviceAvail = true;

      await prefs.setSelectedMode(RecognitionMode.online);
      await speechService.initialize();
      expect(speechService.selectedMode, RecognitionMode.online);

      final success = await speechService.setRecognitionMode(RecognitionMode.offline);
      expect(success, isTrue);
      expect(speechService.selectedMode, RecognitionMode.offline);
      expect(await prefs.getSelectedMode(), RecognitionMode.offline);
    });

    test('Online -> Offline switch fails and preserves Online when pack is missing', () async {
      mockHandler.isOfflineInstalled = false;

      await prefs.setSelectedMode(RecognitionMode.online);
      await speechService.initialize();
      expect(speechService.selectedMode, RecognitionMode.online);

      final success = await speechService.setRecognitionMode(RecognitionMode.offline);
      expect(success, isFalse);

      // Previous preference MUST remain unchanged!
      expect(await prefs.getSelectedMode(), RecognitionMode.online);
      expect(speechService.state, RecognitionState.unavailable);
    });

    test('Recognition service starts listening ONLY with the selected mode', () async {
      mockHandler.isOfflineInstalled = true;
      await speechService.setRecognitionMode(RecognitionMode.offline);

      await speechService.startListening();
      expect(mockHandler.lastStartedMode, 'offline');

      await speechService.stopListening();

      await speechService.setRecognitionMode(RecognitionMode.online);
      await speechService.startListening();
      expect(mockHandler.lastStartedMode, 'online');
    });

    test('Selected mode unavailable sets state to unavailable without auto-switching', () async {
      mockHandler.isOfflineInstalled = true;
      await prefs.setSelectedMode(RecognitionMode.offline);

      // Later, user uninstalls pack or language changes to unsupported
      mockHandler.isOfflineInstalled = false;

      await speechService.initialize();
      expect(speechService.selectedMode, RecognitionMode.offline);
      expect(speechService.state, RecognitionState.unavailable);

      // Must NEVER automatically switch to Online!
      expect(speechService.selectedMode, RecognitionMode.offline);
      expect(await prefs.getSelectedMode(), RecognitionMode.offline);
    });
  });

  group('VoiceCommandMatcher against enabled SQLite commands only', () {
    late CommandDatabaseHelper dbHelper;
    late SqliteVoiceCommandRepository repository;
    late VoiceCommandService commandService;
    late VoiceCommandMatcher matcher;

    setUp(() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${CommandDatabaseHelper.tableName} (
                id TEXT PRIMARY KEY,
                phrase TEXT NOT NULL,
                normalized_phrase TEXT NOT NULL,
                action TEXT NOT NULL,
                is_enabled INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
          },
        ),
      );

      dbHelper = CommandDatabaseHelper(customDatabase: db);
      repository = SqliteVoiceCommandRepository(dbHelper: dbHelper);
      commandService = VoiceCommandService(repository: repository);
      matcher = VoiceCommandMatcher(commandService: commandService);

      // Enabled commands
      await commandService.addCommand(phrase: 'next reel', action: ReelAction.nextReel);
      await commandService.addCommand(phrase: 'aage badho', action: ReelAction.nextReel);
      await commandService.addCommand(phrase: 'pause video', action: ReelAction.pausePlay);

      // Disabled command
      final disabled = await commandService.addCommand(
        phrase: 'scroll up',
        action: ReelAction.previousReel,
        isEnabled: false,
      );
      expect(disabled.isEnabled, isFalse);
    });

    tearDown(() async {
      await dbHelper.close();
    });

    test('Matches enabled command with case-insensitive and normalized speech', () async {
      final match1 = await matcher.matchSpeech(speech: 'NEXT REEL');
      expect(match1, isNotNull);
      expect(match1!.action, ReelAction.nextReel);
      expect(match1.command.phrase, 'next reel');

      final match2 = await matcher.matchSpeech(speech: '  aage   badho  ');
      expect(match2, isNotNull);
      expect(match2!.action, ReelAction.nextReel);
    });

    test('Does NOT match disabled commands', () async {
      final matchDisabled = await matcher.matchSpeech(speech: 'scroll up');
      expect(matchDisabled, isNull);
    });

    test('Returns null for unmapped speech', () async {
      final matchUnmapped = await matcher.matchSpeech(speech: 'something random');
      expect(matchUnmapped, isNull);
    });
  });
}
