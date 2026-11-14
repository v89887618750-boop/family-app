import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Единая точка доступа к локальной базе данных приложения.
///
/// Версия схемы: 15.
/// Все таблицы создаются «сразу в финальном виде» (CREATE TABLE IF NOT EXISTS),
/// а onUpgrade дополнительно правит колонки, поэтому база сходится к
/// правильной схеме из любого старого состояния.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _dbVersion = 15;
  static const String _dbName = 'family_lists.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    _database ??= await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Нужно для работы ON DELETE CASCADE / SET NULL.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ---------------------------------------------------------------------------
  // Схема
  // ---------------------------------------------------------------------------

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        periodicity TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        due_date TEXT,
        due_time TEXT,
        reading_value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        periodicity TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS birthdays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        remind_days INTEGER DEFAULT 1,
        photo_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        forWhom TEXT NOT NULL,
        category TEXT NOT NULL,
        isBought INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        photo_path TEXT,
        reserved_by TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meter_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        reading_value REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS family_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        relation TEXT NOT NULL,
        birthday_id INTEGER,
        photo_path TEXT,
        FOREIGN KEY (birthday_id) REFERENCES birthdays (id) ON DELETE SET NULL
      )
    ''');

    // Связи для фамильного древа.
    //   type = 'father' | 'mother' → a_id является родителем b_id;
    //   type = 'spouse'            → a_id и b_id супруги.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS relations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        a_id INTEGER NOT NULL,
        b_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        FOREIGN KEY (a_id) REFERENCES family_members (id) ON DELETE CASCADE,
        FOREIGN KEY (b_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    // Заметки: и category, и photo_path обязательны начиная с версии 14.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL,
        color INTEGER DEFAULT 0,
        category TEXT,
        photo_path TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meter_readings_task ON meter_readings (task_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks (due_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_gifts_for_whom ON gifts (forWhom)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_relations_a ON relations (a_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_relations_b ON relations (b_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_relations_unique ON relations (a_id, b_id, type)',
    );
  }

  Future<void> _seedCategories(Database db) async {
    const defaults = <String>[
      'Общее',
      'Дом',
      'Семья',
      'Личное',
      'Работа',
      'Праздник',
    ];
    for (final cat in defaults) {
      await db.insert(
        'categories',
        <String, dynamic>{'name': cat},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await _createTables(db);
    await _seedCategories(db);
  }

  /// Миграции «по колонкам»: безопасно доводят любую старую базу до версии 14.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // 1. Создаём таблицы, которых может не быть в очень старых сборках.
    await _createTables(db);

    // 2. Досоздаём колонки, если их нет.
    if (oldVersion < 2) {
      await _ensureColumn(db, 'birthdays', 'remind_days', 'INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      await _ensureColumn(db, 'birthdays', 'photo_path', 'TEXT');
      await _ensureColumn(db, 'gifts', 'note', 'TEXT');
      await _ensureColumn(db, 'gifts', 'photo_path', 'TEXT');
    }
    if (oldVersion < 5) {
      await _ensureColumn(db, 'tasks', 'due_date', 'TEXT');
    }
    if (oldVersion < 6) {
      await _ensureColumn(db, 'tasks', 'reading_value', 'TEXT');
    }
    if (oldVersion < 9) {
      await _ensureColumn(db, 'tasks', 'due_time', 'TEXT');
    }
    if (oldVersion < 10) {
      await _ensureColumn(db, 'purchases', 'note', 'TEXT');
    }
    if (oldVersion < 12) {
      await _ensureColumn(db, 'gifts', 'reserved_by', 'TEXT');
    }
    if (oldVersion < 13) {
      await _ensureColumn(db, 'notes', 'category', 'TEXT');
    }
    if (oldVersion < 14) {
      await _ensureColumn(db, 'notes', 'photo_path', 'TEXT');
    }

    // 3. Базовые категории.
    await _seedCategories(db);
  }

  /// Добавляет колонку только если её реально нет.
  Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
