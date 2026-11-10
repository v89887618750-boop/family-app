import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isDarkMode = false;
  double _fontSize = 1.0; // Коэффициент шрифта

  @override
  void initState() { 
    super.initState(); 
    _loadCategories(); 
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
    });
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('categories');
    setState(() => _categories = maps);
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final controller = TextEditingController(text: category != null ? category['name'] : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Новая категория' : 'Изменить название'),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(labelText: 'Название')
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              
              if (category == null) {
                await db.insert('categories', {'name': controller.text.trim()}, conflictAlgorithm: ConflictAlgorithm.ignore);
              } else {
                // Обновляем название категории
                await db.update('categories', {'name': controller.text.trim()}, where: 'id = ?', whereArgs: [category['id']]);
              }
              if (mounted) Navigator.pop(context);
              _loadCategories();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final catName = category['name'];
    final db = await DatabaseHelper.instance.database;

    // ПРОВЕРКА: есть ли задачи или покупки с этой категорией?
    final tasksCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE category = ?', [catName])) ?? 0;
    final purchasesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM purchases WHERE category = ?', [catName])) ?? 0;

    if (tasksCount > 0 || purchasesCount > 0) {
      // Если есть привязанные записи — ЗАПРЕЩАЕМ удаление
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Нельзя удалить "$catName". К ней привязано дел: $tasksCount, покупок: $purchasesCount. Сначала измените их категорию.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Если записей нет — удаляем
    await db.delete('categories', where: 'id = ?', whereArgs: [category['id']]);
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const ListTile(title: Text('Внешний вид', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          SwitchListTile(
            title: const Text('Тёмная тема'),
            secondary: const Icon(Icons.dark_mode),
            value: _isDarkMode, 
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              widget.onThemeChanged(val); // Меняем тему во всем приложении
            },
          ),
          ListTile(
            title: const Text('Размер шрифта'),
            secondary: const Icon(Icons.format_size),
            subtitle: Slider(
              value: _fontSize,
              min: 0.8,
              max: 1.4,
              divisions: 3,
              label: _fontSize == 0.8 ? 'Мелкий' : _fontSize == 1.0 ? 'Обычный' : _fontSize == 1.2 ? 'Крупный' : 'Очень крупный',
              onChanged: (val) async {
                setState(() => _fontSize = val);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('fontSize', val);
              },
            ),
          ),
          const Divider(),
          const ListTile(title: Text('Категории', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ..._categories.map((cat) => ListTile(
                title: Text(cat['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showCategoryDialog(category: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCategory(cat),
                    ),
                  ],
                ),
              )),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text('Добавить категорию'),
            onTap: () => _showCategoryDialog(),
          ),
          const Divider(),
          const ListTile(title: Text('О приложении', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const ListTile(leading: Icon(Icons.family_restroom, color: Colors.teal), title: Text('Volkov Family App'), subtitle: Text('Версия 2.0.0')),
        ],
      ),
    );
  }
}
