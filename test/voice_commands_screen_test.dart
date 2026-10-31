import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:reelsense/features/commands/data/command_database_helper.dart';
import 'package:reelsense/features/commands/data/voice_command_repository.dart';
import 'package:reelsense/features/commands/models/reel_action.dart';
import 'package:reelsense/features/commands/screens/voice_commands_screen.dart';
import 'package:reelsense/features/commands/services/voice_command_service.dart';

Future<void> pumpAsync(WidgetTester tester, [int millis = 150]) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(Duration(milliseconds: millis));
    });
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late CommandDatabaseHelper dbHelper;
  late SqliteVoiceCommandRepository repository;
  late VoiceCommandService service;

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
    service = VoiceCommandService(repository: repository);

    // Seed test commands
    await service.addCommand(phrase: 'next', action: ReelAction.nextReel);
    await service.addCommand(phrase: 'previous', action: ReelAction.previousReel);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  testWidgets('VoiceCommandsScreen displays list, search, and action filters',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCommandsScreen(service: service),
      ),
    );
    await pumpAsync(tester);

    expect(find.text('Voice Commands Manager'), findsOneWidget);
    expect(find.text('"next"'), findsOneWidget);
    expect(find.text('"previous"'), findsOneWidget);

    // Search for "next"
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'next');
    await pumpAsync(tester);

    expect(find.text('"next"'), findsOneWidget);
    expect(find.text('"previous"'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await pumpAsync(tester);

    expect(find.text('"next"'), findsOneWidget);
    expect(find.text('"previous"'), findsOneWidget);
  });

  testWidgets('Add new command via FloatingActionButton and sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCommandsScreen(service: service),
      ),
    );
    await pumpAsync(tester);

    // Tap Add Command FAB
    await tester.tap(find.text('Add Command'));
    await tester.pumpAndSettle();

    expect(find.text('New Voice Command'), findsOneWidget);

    // Enter phrase
    final phraseField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(phraseField, 'aage badho');
    await tester.pumpAndSettle();

    // Tap Save Command
    await tester.tap(find.text('Save Command'));
    await pumpAsync(tester, 200);

    // Verify it now appears on screen
    expect(find.text('"aage badho"'), findsOneWidget);
  });

  testWidgets('Delete command with confirmation dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCommandsScreen(service: service),
      ),
    );
    await pumpAsync(tester);

    expect(find.text('"previous"'), findsOneWidget);

    // Tap delete icon on second command
    final deleteIcons = find.byIcon(Icons.delete_outline_rounded);
    await tester.tap(deleteIcons.at(1));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Delete Voice Command?'), findsOneWidget);

    // Tap Delete
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await pumpAsync(tester, 200);

    // Verify deleted
    expect(find.text('"previous"'), findsNothing);
  });
}
