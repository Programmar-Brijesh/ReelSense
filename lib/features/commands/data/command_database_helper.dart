import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'default_commands.dart';

class CommandDatabaseHelper {
  static const String tableName = 'voice_commands';
  static const String databaseName = 'reelsense_voice_commands.db';
  static const int databaseVersion = 1;

  static final CommandDatabaseHelper instance = CommandDatabaseHelper._internal();
  Database? _database;

  CommandDatabaseHelper._internal();

  factory CommandDatabaseHelper({Database? customDatabase}) {
    if (customDatabase != null) {
      final helper = CommandDatabaseHelper._internal();
      helper._database = customDatabase;
      return helper;
    }
    return instance;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase(databaseName);
    return _database!;
  }

  Future<Database> _initDatabase(
    String name, {
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = await dbFactory.getDatabasesPath();
    final path = join(dbPath, name);

    return await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        phrase TEXT NOT NULL,
        normalized_phrase TEXT NOT NULL,
        action TEXT NOT NULL,
        is_enabled INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_voice_commands_normalized 
      ON $tableName (normalized_phrase)
    ''');

    // Seed default commands
    final defaults = DefaultCommands.getDefaultCommands();
    final batch = db.batch();
    for (final cmd in defaults) {
      batch.insert(tableName, cmd.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations will be handled here
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
