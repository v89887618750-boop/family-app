import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Единая точка доступа к локальной базе данных приложения.
///
/// Версия схемы: 16 (добавлена подготовка к синхронизации).
///
/// Схема приводится к финальному виду из любого старого состояния:
/// таблицы создаются через `CREATE TABLE IF NOT EXISTS`, недостающие колонки
/// досоздаются через `ALTER TABLE` после проверки `PRAGMA table_info`.
///
/// Синхронизация:
///   * в каждой синхронизируемой таблице есть `sync_id` (UUID строки)
///     и `updated_at` (мс epoch) — их автоматически заполняют SQLite-триггеры;
///   * удаления фиксируются в `sync_tombstones`, чтобы «удалённое» не
///     воскресало с другого устройства;
///   * прогресс обмена хранится в `sync_meta`.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int _dbVersion = 16;
  static const String _dbName = 'family_lists.db';

  /// Таблицы, которые участвуют в синхронизации.
  static const List<String> syncTables = <String>[
    'birthdays',
    'tasks',
    'purchases',
    'gifts',
    'categories',
    'notes',
    'family_members',
    'relations',
    'meter_readings',
  ];

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
        reading_value TEXT,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        periodicity TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS birthdays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        remind_days INTEGER DEFAULT 1,
        photo_path TEXT,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0
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
        reserved_by TEXT,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meter_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        reading_value REAL NOT NULL,
        date TEXT NOT NULL,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0,
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
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0,
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
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0,
        FOREIGN KEY (a_id) REFERENCES family_members (id) ON DELETE CASCADE,
        FOREIGN KEY (b_id) REFERENCES family_members (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        date TEXT NOT NULL,
        color INTEGER DEFAULT 0,
        category TEXT,
        photo_path TEXT,
        sync_id TEXT,
        updated_at INTEGER DEFAULT 0
      )
    ''');

    // Удалённые записи: чтобы удаление на одном устройстве доехало до других.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_tombstones (
        sync_id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        deleted_at INTEGER NOT NULL
      )
    ''');

    // Служебные значения синхронизации (водяные знаки push/pull и т.п.).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT
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

  // ---------------------------------------------------------------------------
  // Подготовка синхронизации
  // ---------------------------------------------------------------------------

  /// Заполняет sync_id / updated_at у существующих строк и создаёт индексы.
  Future<void> _backfillSync(Database db) async {
    for (final table in syncTables) {
      await db.execute(
        "UPDATE $table SET sync_id = lower(hex(randomblob(16))) "
        "WHERE sync_id IS NULL OR sync_id = ''",
      );
      await db.execute(
        'UPDATE $table SET updated_at = 1 WHERE updated_at IS NULL OR updated_at = 0',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_${table}_sync ON $table (sync_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS ix_${table}_updated ON $table (updated_at)',
      );
    }
  }

  /// Триггеры:
  ///   * INSERT — выдают sync_id и время, если их не передали явно;
  ///   * UPDATE — поднимает updated_at, если запись правили из приложения
  ///     (при синхронизации updated_at передаётся явно и сохраняется как есть).
  ///
  /// Рекурсивные триггеры в SQLite по умолчанию выключены, поэтому UPDATE
  /// внутри триггера не вызывает этот же триггер повторно.
  Future<void> _createSyncTriggers(Database db) async {
    for (final table in syncTables) {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_insert
        AFTER INSERT ON $table
        BEGIN
          UPDATE $table
          SET sync_id = COALESCE(NEW.sync_id, lower(hex(randomblob(16)))),
              updated_at = CASE
                WHEN NEW.updated_at IS NULL OR NEW.updated_at = 0
                THEN CAST(strftime('%s', 'now') AS INTEGER) * 1000
                ELSE NEW.updated_at
              END
          WHERE id = NEW.id;
        END
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_update
        AFTER UPDATE ON $table
        BEGIN
          UPDATE $table
          SET updated_at = CASE
                WHEN NEW.updated_at IS OLD.updated_at
                THEN CAST(strftime('%s', 'now') AS INTEGER) * 1000
                ELSE NEW.updated_at
              END
          WHERE id = NEW.id AND NEW.sync_id IS NOT NULL;
        END
      ''');
    }
  }

  Future<void> _ensureSyncColumns(Database db) async {
    for (final table in syncTables) {
      await _ensureColumn(db, table, 'sync_id', 'TEXT');
      await _ensureColumn(db, table, 'updated_at', 'INTEGER DEFAULT 0');
    }
  }

  // ---------------------------------------------------------------------------
  // Создание и миграции
  // ---------------------------------------------------------------------------

  Future<void> _createDB(Database db, int version) async {
    await _createTables(db);
    await _ensureSyncColumns(db);
    await _backfillSync(db);
    await _createSyncTriggers(db);
    await _seedCategories(db);
  }

  /// Миграции «по колонкам»: безопасно доводят любую старую базу до версии 16.
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

    // 3. Подготовка синхронизации (v16).
    await _ensureSyncColumns(db);
    await _backfillSync(db);
    await _createSyncTriggers(db);

    // 4. Базовые категории.
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
