import 'package:sqflite/sqflite.dart';
import '../models/reel_action.dart';
import '../models/voice_command.dart';
import 'command_database_helper.dart';
import 'default_commands.dart';

abstract class VoiceCommandRepository {
  Future<List<VoiceCommand>> getAllCommands();
  Future<VoiceCommand?> getCommandById(String id);
  Future<VoiceCommand?> getCommandByNormalizedPhrase(String normalizedPhrase);
  Future<List<VoiceCommand>> getCommandsByAction(ReelAction action);
  Future<int> insertCommand(VoiceCommand command);
  Future<int> updateCommand(VoiceCommand command);
  Future<int> deleteCommand(String id);
  Future<void> resetToDefaults();
}

class SqliteVoiceCommandRepository implements VoiceCommandRepository {
  final CommandDatabaseHelper _dbHelper;

  SqliteVoiceCommandRepository({CommandDatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? CommandDatabaseHelper.instance;

  @override
  Future<List<VoiceCommand>> getAllCommands() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.tableName,
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => VoiceCommand.fromMap(m)).toList();
  }

  @override
  Future<VoiceCommand?> getCommandById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return VoiceCommand.fromMap(maps.first);
  }

  @override
  Future<VoiceCommand?> getCommandByNormalizedPhrase(
      String normalizedPhrase) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.tableName,
      where: 'normalized_phrase = ?',
      whereArgs: [normalizedPhrase],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return VoiceCommand.fromMap(maps.first);
  }

  @override
  Future<List<VoiceCommand>> getCommandsByAction(ReelAction action) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.tableName,
      where: 'action = ?',
      whereArgs: [action.dbValue],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => VoiceCommand.fromMap(m)).toList();
  }

  @override
  Future<int> insertCommand(VoiceCommand command) async {
    final db = await _dbHelper.database;
    return await db.insert(
      CommandDatabaseHelper.tableName,
      command.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<int> updateCommand(VoiceCommand command) async {
    final db = await _dbHelper.database;
    return await db.update(
      CommandDatabaseHelper.tableName,
      command.toMap(),
      where: 'id = ?',
      whereArgs: [command.id],
    );
  }

  @override
  Future<int> deleteCommand(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      CommandDatabaseHelper.tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> resetToDefaults() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(CommandDatabaseHelper.tableName);
      final defaults = DefaultCommands.getDefaultCommands();
      final batch = txn.batch();
      for (final cmd in defaults) {
        batch.insert(CommandDatabaseHelper.tableName, cmd.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
