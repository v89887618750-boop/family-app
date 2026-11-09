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
    // Версия 4: добавлены фото для ДР и заметки/фото для подарков
    return await openDatabase(path, version: 4, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    // Таблица дел
    await db.execute('''CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      title TEXT NOT NULL, 
      category TEXT NOT NULL, 
      periodicity TEXT NOT NULL, 
      isCompleted INTEGER NOT NULL
    )''');

    // Таблица покупок
    await db.execute('''CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      title TEXT NOT NULL, 
      category TEXT NOT NULL, 
      periodicity TEXT NOT NULL, 
      isCompleted INTEGER NOT NULL
    )''');

    // Таблица дней рождения (с напоминаниями и аватаркой)
    await db.execute('''CREATE TABLE birthdays (
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      name TEXT NOT NULL, 
      date TEXT NOT NULL, 
      category TEXT NOT NULL, 
      remind_days INTEGER DEFAULT 1, 
      photo_path TEXT
    )''');

    // Таблица подарков (с заметками и фото)
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
    
    // Добавляем базовые категории при первом запуске
    for (var cat in ['Общее', 'Дом', 'Семья', 'Личное', 'Работа', 'Праздник']) {
      await db.insert('categories', {'name': cat}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Обновление до версии 2 (напоминания для ДР)
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE birthdays ADD COLUMN remind_days INTEGER DEFAULT 1');
    }
    
    // Обновление до версии 4 (фото и заметки)
    if (oldVersion < 4) {
      // Добавляем колонки, если их еще нет
      try {
        await db.execute('ALTER TABLE birthdays ADD COLUMN photo_path TEXT');
      } catch (e) {
        // Колонка уже существует
      }
      try {
        await db.execute('ALTER TABLE gifts ADD COLUMN note TEXT');
      } catch (e) {
        // Колонка уже существует
      }
      try {
        await db.execute('ALTER TABLE gifts ADD COLUMN photo_path TEXT');
      } catch (e) {
        // Колонка уже существует
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
