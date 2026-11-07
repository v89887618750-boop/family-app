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
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }
  Future _createDB(Database db, int version) async {
    await db.execute('''CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT NOT NULL, periodicity TEXT NOT NULL, isCompleted INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE purchases (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, category TEXT NOT NULL, periodicity TEXT NOT NULL, isCompleted INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE birthdays (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, date TEXT NOT NULL, category TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE gifts (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, forWhom TEXT NOT NULL, category TEXT NOT NULL, isBought INTEGER NOT NULL)''');
  }
}
