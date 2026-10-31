import 'package:sqflite/sqflite.dart';
import '../../commands/data/command_database_helper.dart';
import '../models/custom_gesture.dart';

abstract class CustomGestureRepository {
  Future<List<CustomGesture>> getAllGestures();
  Future<List<CustomGesture>> getEnabledGestures();
  Future<CustomGesture?> getGestureById(String id);
  Future<int> createGesture(CustomGesture gesture);
  Future<int> updateGesture(CustomGesture gesture);
  Future<int> deleteGesture(String id);
  Future<int> updateGestureStatus(String id, bool isEnabled);
}

class SqliteCustomGestureRepository implements CustomGestureRepository {
  final CommandDatabaseHelper _dbHelper;

  SqliteCustomGestureRepository({CommandDatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? CommandDatabaseHelper.instance;

  @override
  Future<List<CustomGesture>> getAllGestures() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.customGesturesTableName,
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => CustomGesture.fromMap(m)).toList();
  }

  @override
  Future<List<CustomGesture>> getEnabledGestures() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.customGesturesTableName,
      where: 'is_enabled = ?',
      whereArgs: [1],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => CustomGesture.fromMap(m)).toList();
  }

  @override
  Future<CustomGesture?> getGestureById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      CommandDatabaseHelper.customGesturesTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CustomGesture.fromMap(maps.first);
  }

  @override
  Future<int> createGesture(CustomGesture gesture) async {
    final db = await _dbHelper.database;
    return await db.insert(
      CommandDatabaseHelper.customGesturesTableName,
      gesture.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<int> updateGesture(CustomGesture gesture) async {
    final db = await _dbHelper.database;
    return await db.update(
      CommandDatabaseHelper.customGesturesTableName,
      gesture.toMap(),
      where: 'id = ?',
      whereArgs: [gesture.id],
    );
  }

  @override
  Future<int> deleteGesture(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      CommandDatabaseHelper.customGesturesTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> updateGestureStatus(String id, bool isEnabled) async {
    final db = await _dbHelper.database;
    return await db.update(
      CommandDatabaseHelper.customGesturesTableName,
      {
        'is_enabled': isEnabled ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
