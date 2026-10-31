import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:reelsense/features/commands/data/command_database_helper.dart';
import 'package:reelsense/features/commands/data/voice_command_repository.dart';
import 'package:reelsense/features/commands/models/reel_action.dart';
import 'package:reelsense/features/commands/models/voice_command.dart';
import 'package:reelsense/features/commands/services/voice_command_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CommandDatabaseHelper dbHelper;
  late SqliteVoiceCommandRepository repository;
  late VoiceCommandService service;

  setUp(() async {
    // Unique in-memory database for each test to isolate states
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
    service = VoiceCommandService(repository: repository);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('VoiceCommand Model and Normalization Tests', () {
    test('Normalizes phrase correctly (trimming, collapsing spaces, lowercasing)', () {
      expect(VoiceCommand.normalize('   NEXT    REEL  '), 'next reel');
      expect(VoiceCommand.normalize('Aage   Badho'), 'aage badho');
      expect(VoiceCommand.normalize('  अगला   रील  '), 'अगला रील');
    });

    test('Case-insensitive normalization comparison', () {
      final p1 = VoiceCommand.normalize('SCROLL DOWN');
      final p2 = VoiceCommand.normalize('scroll   down');
      expect(p1, equals(p2));
    });
  });

  group('VoiceCommandService CRUD & Validation Tests', () {
    test('Creating commands and reading from database', () async {
      final cmd = await service.addCommand(
        phrase: 'skip',
        action: ReelAction.nextReel,
      );

      expect(cmd.phrase, 'skip');
      expect(cmd.normalizedPhrase, 'skip');
      expect(cmd.action, ReelAction.nextReel);
      expect(cmd.isEnabled, isTrue);

      final all = await service.getAllCommands();
      expect(all.length, 1);
      expect(all.first.phrase, 'skip');
    });

    test('Editing an existing command', () async {
      final cmd = await service.addCommand(
        phrase: 'ruk jao',
        action: ReelAction.pausePlay,
      );

      final updated = await service.updateCommand(
        id: cmd.id,
        phrase: 'roko',
        action: ReelAction.pausePlay,
        isEnabled: false,
      );

      expect(updated.phrase, 'roko');
      expect(updated.normalizedPhrase, 'roko');
      expect(updated.isEnabled, isFalse);

      final fetched = await repository.getCommandById(cmd.id);
      expect(fetched?.phrase, 'roko');
      expect(fetched?.isEnabled, isFalse);
    });

    test('Deleting a command', () async {
      final cmd = await service.addCommand(
        phrase: 'replay video',
        action: ReelAction.replayReel,
      );

      expect((await service.getAllCommands()).length, 1);

      await service.deleteCommand(cmd.id);
      expect((await service.getAllCommands()).isEmpty, isTrue);
    });

    test('Enable / disable command functionality', () async {
      final cmd = await service.addCommand(
        phrase: 'favourite',
        action: ReelAction.likeReel,
        isEnabled: true,
      );

      await service.toggleCommand(cmd.id, false);
      var fetched = await repository.getCommandById(cmd.id);
      expect(fetched?.isEnabled, isFalse);

      await service.toggleCommand(cmd.id, true);
      fetched = await repository.getCommandById(cmd.id);
      expect(fetched?.isEnabled, isTrue);
    });

    test('Rejects empty or whitespace-only phrases', () async {
      final validation1 = await service.validatePhrase(
        phrase: '',
        action: ReelAction.nextReel,
      );
      expect(validation1.isValid, isFalse);
      expect(validation1.errorMessage, contains('cannot be empty'));

      final validation2 = await service.validatePhrase(
        phrase: '     ',
        action: ReelAction.nextReel,
      );
      expect(validation2.isValid, isFalse);
    });

    test('Duplicate detection: prevents duplicate phrase for same action', () async {
      await service.addCommand(
        phrase: 'next reel',
        action: ReelAction.nextReel,
      );

      // Attempt exact match
      final valExact = await service.validatePhrase(
        phrase: 'next reel',
        action: ReelAction.nextReel,
      );
      expect(valExact.isValid, isFalse);
      expect(valExact.errorMessage, contains('already registered'));

      // Attempt case-insensitive match with extra spaces
      final valFuzzy = await service.validatePhrase(
        phrase: '   NEXT   REEL  ',
        action: ReelAction.nextReel,
      );
      expect(valFuzzy.isValid, isFalse);
      expect(valFuzzy.errorMessage, contains('already registered'));
    });

    test('Multiple different phrases for the same action are allowed', () async {
      await service.addCommand(
        phrase: 'next',
        action: ReelAction.nextReel,
      );

      final valSecond = await service.validatePhrase(
        phrase: 'scroll down',
        action: ReelAction.nextReel,
      );
      expect(valSecond.isValid, isTrue);

      await service.addCommand(
        phrase: 'scroll down',
        action: ReelAction.nextReel,
      );

      final valHindi = await service.validatePhrase(
        phrase: 'अगला रील',
        action: ReelAction.nextReel,
      );
      expect(valHindi.isValid, isTrue);

      await service.addCommand(
        phrase: 'अगला रील',
        action: ReelAction.nextReel,
      );

      final allNext = await repository.getCommandsByAction(ReelAction.nextReel);
      expect(allNext.length, 3);
    });

    test('Conflicting action validation: duplicate phrase across different actions rejected when enabled', () async {
      await service.addCommand(
        phrase: 'pause',
        action: ReelAction.pausePlay,
        isEnabled: true,
      );

      // Attempt to register 'pause' for NEXT_REEL while enabled
      final validation = await service.validatePhrase(
        phrase: 'pause',
        action: ReelAction.nextReel,
        isEnabled: true,
      );

      expect(validation.isValid, isFalse);
      expect(validation.errorMessage, contains('conflicts with active action'));
    });

    test('Search and filter commands by query and action', () async {
      await service.addCommand(phrase: 'scroll up', action: ReelAction.previousReel);
      await service.addCommand(phrase: 'scroll down', action: ReelAction.nextReel);
      await service.addCommand(phrase: 'piche jao', action: ReelAction.previousReel);

      // Search by text "scroll"
      final scrollResults = await service.searchAndFilterCommands(query: 'scroll');
      expect(scrollResults.length, 2);

      // Search by text "scroll" + filtered to PREVIOUS_REEL
      final filteredResults = await service.searchAndFilterCommands(
        query: 'scroll',
        actionFilter: ReelAction.previousReel,
      );
      expect(filteredResults.length, 1);
      expect(filteredResults.first.phrase, 'scroll up');

      // Search Hindi / Hinglish phrase
      final hinglishResults = await service.searchAndFilterCommands(query: 'piche');
      expect(hinglishResults.length, 1);
    });

    test('Reset to default initial command set', () async {
      await service.addCommand(phrase: 'custom_command', action: ReelAction.likeReel);
      expect((await service.getAllCommands()).length, 1);

      await service.resetToDefaults();
      final commands = await service.getAllCommands();
      expect(commands.length, greaterThanOrEqualTo(15));
      expect(commands.any((c) => c.phrase == 'next'), isTrue);
      expect(commands.any((c) => c.phrase == 'अगला रील'), isTrue);
    });
  });
}
