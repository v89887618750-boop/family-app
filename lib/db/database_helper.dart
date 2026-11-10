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
    // Версия 8: добавлена таблица членов семьи
    return await openDatabase(path, version: 8, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    // Таблица дел
    await db.execute('''CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      title TEXT NOT NULL, 
      category TEXT NOT NULL, 
      periodicity TEXT NOT NULL, 
      isCompleted INTEGER NOT NULL,
      due_date TEXT,
      reading_value TEXT
    )''');

    // Таблица покупок
    await db.execute('''CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      title TEXT NOT NULL, 
      category TEXT NOT NULL, 
      periodicity TEXT NOT NULL, 
      isCompleted INTEGER NOT NULL
    )''');

    // Таблица дней рождения
    await db.execute('''CREATE TABLE birthdays (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      name TEXT NOT NULL, 
      date TEXT NOT NULL, 
      category TEXT NOT NULL, 
      remind_days INTEGER DEFAULT 1, 
      photo_path TEXT
    )''');

    // Таблица подарков
    await db.execute('''CREATE TABLE gifts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      title TEXT NOT NULL, 
      forWhom TEXT NOT NULL, 
      category TEXT NOT NULL, 
      isBought INTEGER NOT NULL,
      note TEXT,
      photo_path TEXT
    )''');

    // Таблица категорий
    await db.execute('''CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      name TEXT NOT NULL UNIQUE
    )''');

    // Таблица истории показаний счетчиков
    await db.execute('''CREATE TABLE meter_readings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL,
      reading_value REAL NOT NULL,
      date TEXT NOT NULL,
      FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
    )''');

    // НОВАЯ ТАБЛИЦА: Члены семьи
    await db.execute('''CREATE TABLE family_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      relation TEXT NOT NULL,
      birthday_id INTEGER,
      photo_path TEXT,
      FOREIGN KEY (birthday_id) REFERENCES birthdays (id) ON DELETE SET NULL
    )''');
    
    // Добавляем базовые категории
    for (var cat in ['Общее', 'Дом', 'Семья', 'Личное', 'Работа', 'Праздник']) {
      await db.insert('categories', {'name': cat}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE birthdays ADD COLUMN remind_days INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE birthdays ADD COLUMN photo_path TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE gifts ADD COLUMN note TEXT'); } catch (e) {}
      try { await db.execute('ALTER TABLE gifts ADD COLUMN photo_path TEXT'); } catch (e) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT'); } catch (e) {}
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE tasks ADD COLUMN reading_value TEXT'); } catch (e) {}
    }
    if (oldVersion < 7) {
      await db.execute('''CREATE TABLE meter_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        reading_value REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )''');
    }
    // ОБНОВЛЕНИЕ ДО ВЕРСИИ 8 (Члены семьи)
    if (oldVersion < 8) {
      await db.execute('''CREATE TABLE family_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        relation TEXT NOT NULL,
        birthday_id INTEGER,
        photo_path TEXT,
        FOREIGN KEY (birthday_id) REFERENCES birthdays (id) ON DELETE SET NULL
      )''');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
