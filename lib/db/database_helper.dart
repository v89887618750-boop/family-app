import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('family_lists.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // Версия 14: добавлен family_id во все таблицы для разделения семей
    return await openDatabase(path, version: 14, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, title TEXT NOT NULL, category TEXT NOT NULL, 
      periodicity TEXT NOT NULL, isCompleted INTEGER NOT NULL, due_date TEXT, due_time TEXT, reading_value TEXT
    )''');

    await db.execute('''CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, title TEXT NOT NULL, category TEXT NOT NULL, 
      periodicity TEXT NOT NULL, isCompleted INTEGER NOT NULL, note TEXT
    )''');

    await db.execute('''CREATE TABLE birthdays (
      id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, name TEXT NOT NULL, date TEXT NOT NULL, 
      category TEXT NOT NULL, remind_days INTEGER DEFAULT 1, photo_path TEXT
    )''');

    await db.execute('''CREATE TABLE gifts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, title TEXT NOT NULL, forWhom TEXT NOT NULL, 
      category TEXT NOT NULL, isBought INTEGER NOT NULL, note TEXT, photo_path TEXT, reserved_by TEXT
    )''');

    await db.execute('''CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, name TEXT NOT NULL)''');
    
    await db.execute('''CREATE TABLE meter_readings (
      id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL, reading_value REAL NOT NULL, 
      date TEXT NOT NULL, FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
    )''');

    await db.execute('''CREATE TABLE family_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, name TEXT NOT NULL, relation TEXT NOT NULL, 
      birthday_id INTEGER, photo_path TEXT, FOREIGN KEY (birthday_id) REFERENCES birthdays (id) ON DELETE SET NULL
    )''');

    await db.execute('''CREATE TABLE notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL, title TEXT NOT NULL, content TEXT NOT NULL, 
      date TEXT NOT NULL, color INTEGER DEFAULT 0, category TEXT
    )''');
    
    for (var cat in ['Общее', 'Дом', 'Семья', 'Личное', 'Работа', 'Праздник']) {
      await db.insert('categories', {'family_id': 'default', 'name': cat}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await db.execute('ALTER TABLE birthdays ADD COLUMN remind_days INTEGER DEFAULT 1');
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE birthdays ADD COLUMN photo_path TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE gifts ADD COLUMN note TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE gifts ADD COLUMN photo_path TEXT'); } catch (e) {}
    }
    if (oldVersion < 5) try { await db.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT'); } catch (e) {}
    if (oldVersion < 6) try { await db.execute('ALTER TABLE tasks ADD COLUMN reading_value TEXT'); } catch (e) {}
    if (oldVersion < 7) {
      await db.execute('''CREATE TABLE meter_readings (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER NOT NULL, reading_value REAL NOT NULL, date TEXT NOT NULL, FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE)''');
    }
    if (oldVersion < 8) {
      await db.execute('''CREATE TABLE family_members (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, relation TEXT NOT NULL, birthday_id INTEGER, photo_path TEXT, FOREIGN KEY (birthday_id) REFERENCES birthdays (id) ON DELETE SET NULL)''');
    }
    if (oldVersion < 9) try { await db.execute('ALTER TABLE tasks ADD COLUMN due_time TEXT'); } catch (e) {}
    if (oldVersion < 10) try { await db.execute('ALTER TABLE purchases ADD COLUMN note TEXT'); } catch (e) {}
    if (oldVersion < 11) {
      await db.execute('''CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, content TEXT NOT NULL, date TEXT NOT NULL, color INTEGER DEFAULT 0)''');
    }
    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE gifts ADD COLUMN reserved_by TEXT'); } catch (e) {}
    }
    if (oldVersion < 13) {
      try { await db.execute('ALTER TABLE notes ADD COLUMN category TEXT'); } catch (e) {}
    }
    // ОБНОВЛЕНИЕ ДО ВЕРСИИ 14 (Мультиарендность)
    if (oldVersion < 14) {
      // Добавляем family_id во все таблицы. По умолчанию ставим 'default', чтобы не потерять старые данные.
      try { await db.execute("ALTER TABLE tasks ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
      try { await db.execute("ALTER TABLE purchases ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
      try { await db.execute("ALTER TABLE birthdays ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
      try { await db.execute("ALTER TABLE gifts ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
      try { await db.execute("ALTER TABLE family_members ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
      try { await db.execute("ALTER TABLE notes ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
      try { await db.execute("ALTER TABLE categories ADD COLUMN family_id TEXT NOT NULL DEFAULT 'default'"); } catch (e) {}
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
