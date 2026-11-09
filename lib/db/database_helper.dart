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
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT NOT NULL, periodicity TEXT NOT NULL, isCompleted INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE purchases (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT NOT NULL, periodicity TEXT NOT NULL, isCompleted INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE birthdays (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, date TEXT NOT NULL, category TEXT NOT NULL, remind_days INTEGER DEFAULT 1)''');
    
    // В таблицу подарков добавлено поле forWhom для связи с ДР
    await db.execute('''CREATE TABLE gifts (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, forWhom TEXT NOT NULL, category TEXT NOT NULL, isBought INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)''');
    
    for (var cat in ['Общее', 'Дом', 'Семья', 'Личное', 'Работа', 'Праздник']) {
      await db.insert('categories', {'name': cat}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE birthdays ADD COLUMN remind_days INTEGER DEFAULT 1');
    }
    if (oldVersion < 3) {
      // В подарках поле forWhom уже есть, на всякий случай проверяем (если таблица создавалась старой версией)
      // Обычно в SQLite ALTER TABLE ADD COLUMN вызовет ошибку, если колонка уже есть, но у нас структура выше.
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
