import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../utils/family_manager.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(double) onFontSizeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged, required this.onFontSizeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isDarkMode = false;
  double _fontSize = 1.0;
  String _familyId = '';
  final _joinController = TextEditingController();

  @override
  void initState() { 
    super.initState(); 
    _loadCategories(); 
    _loadPrefs();
    _loadFamilyId();
  }

  Future<void> _loadFamilyId() async {
    final id = await FamilyManager.getFamilyId();
    setState(() => _familyId = id);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
    });
  }

  Future<void> _loadCategories() async {
    final familyId = await FamilyManager.getFamilyId();
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('categories', where: 'family_id = ?', whereArgs: [familyId]);
    setState(() => _categories = maps);
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final controller = TextEditingController(text: category != null ? category['name'] : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Новая категория' : 'Изменить название'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final familyId = await FamilyManager.getFamilyId();
              final db = await DatabaseHelper.instance.database;
              if (category == null) {
                await db.insert('categories', {'family_id': familyId, 'name': controller.text.trim()}, conflictAlgorithm: ConflictAlgorithm.ignore);
              } else {
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
    final tasksCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE category = ?', [catName])) ?? 0;
    final purchasesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM purchases WHERE category = ?', [catName])) ?? 0;

    if (tasksCount > 0 || purchasesCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нельзя удалить "$catName". К ней привязано дел: $tasksCount.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    await db.delete('categories', where: 'id = ?', whereArgs: [category['id']]);
    _loadCategories();
  }

  Future<void> _joinFamily() async {
    if (_joinController.text.trim().isEmpty) return;
    
    // Меняем ID семьи
    await FamilyManager.setFamilyId(_joinController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы вошли в новую семью! Перезапустите приложение.')),
      );
      // Обновляем ID на экране
      _loadFamilyId();
      _loadCategories();
      _joinController.clear();
    }
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
              widget.onThemeChanged(val); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Размер шрифта'),
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
                widget.onFontSizeChanged(val);
              },
            ),
          ),
          
          const Divider(),
          const ListTile(title: Text('Семейная комната', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            leading: const Icon(Icons.vpn_key, color: Colors.teal),
            title: const Text('Ваш ID семьи'),
            subtitle: Text(_familyId, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _familyId));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID скопирован в буфер обмена')));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinController,
                    decoration: const InputDecoration(
                      labelText: 'Ввести ID жены/мужа',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _joinFamily,
                  child: const Text('Войти'),
                ),
              ],
            ),
          ),

          const Divider(),
          const ListTile(title: Text('Категории', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ..._categories.map((cat) => ListTile(
                title: Text(cat['name']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showCategoryDialog(category: cat)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCategory(cat)),
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
