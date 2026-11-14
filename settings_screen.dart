import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';

/// Настройки приложения: тема, размер шрифта, категории.
/// Идентификатор семьи здесь больше не нужен и не показывается.
class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(double) onFontSizeChanged;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isDarkMode = false;
  double _fontSize = 1.0;
  String _profileName = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadCategories();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
      _profileName = prefs.getString('my_name') ?? '';
    });
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    if (!mounted) return;
    setState(() => _categories = maps);
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _showCategoryDialog({Map<String, dynamic>? category}) async {
    final controller = TextEditingController(
      text: category == null ? '' : (category['name'] as String? ?? ''),
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == null ? 'Новая категория' : 'Изменить название',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                _showMessage('Введите название категории');
                return;
              }

              try {
                final db = await DatabaseHelper.instance.database;
                if (category == null) {
                  await db.insert(
                    'categories',
                    {'name': name},
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                } else {
                  final oldName = category['name'] as String? ?? '';
                  await db.update(
                    'categories',
                    {'name': name},
                    where: 'id = ?',
                    whereArgs: [category['id']],
                  );
                  // Переименовываем категорию во всех связанных записях,
                  // чтобы дела и покупки не «потеряли» её.
                  if (oldName.isNotEmpty && oldName != name) {
                    await _renameCategoryEverywhere(oldName, name);
                  }
                }
                if (mounted) Navigator.pop(dialogContext);
                await _loadCategories();
              } catch (e) {
                _showMessage('Ошибка: $e', isError: true);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameCategoryEverywhere(String oldName, String newName) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'tasks',
      {'category': newName},
      where: 'category = ?',
      whereArgs: [oldName],
    );
    await db.update(
      'purchases',
      {'category': newName},
      where: 'category = ?',
      whereArgs: [oldName],
    );
    await db.update(
      'notes',
      {'category': newName},
      where: 'category = ?',
      whereArgs: [oldName],
    );
  }

  Future<int> _countUsage(String table, String categoryName) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE category = ?',
      [categoryName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final name = category['name'] as String? ?? '';

    final tasksCount = await _countUsage('tasks', name);
    final purchasesCount = await _countUsage('purchases', name);

    if (tasksCount > 0 || purchasesCount > 0) {
      _showMessage(
        'Нельзя удалить "$name": привязано дел — $tasksCount, покупок — $purchasesCount.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('Удалить категорию "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseHelper.instance.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [category['id']]);
    await _loadCategories();
  }

  String get _fontSizeLabel {
    if (_fontSize < 0.95) return 'Мелкий';
    if (_fontSize < 1.15) return 'Обычный';
    if (_fontSize < 1.35) return 'Крупный';
    return 'Очень крупный';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'Внешний вид',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SwitchListTile(
            title: const Text('Тёмная тема'),
            secondary: const Icon(Icons.dark_mode),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              widget.onThemeChanged(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Размер шрифта'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _fontSize,
                  min: 0.8,
                  max: 1.4,
                  divisions: 3,
                  label: _fontSizeLabel,
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                    widget.onFontSizeChanged(value);
                  },
                ),
                Text(_fontSizeLabel),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'Категории',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text('Используются в делах и покупках'),
          ),
          if (_categories.isEmpty)
            const ListTile(
              title: Text('Категорий нет', style: TextStyle(color: Colors.grey)),
            ),
          ..._categories.map((cat) {
            final name = cat['name'] as String? ?? '';
            return ListTile(
              leading: const Icon(Icons.label_outline, color: Colors.teal),
              title: Text(name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    tooltip: 'Переименовать',
                    onPressed: () => _showCategoryDialog(category: cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Удалить',
                    onPressed: () => _deleteCategory(cat),
                  ),
                ],
              ),
            );
          }),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text('Добавить категорию'),
            onTap: () => _showCategoryDialog(),
          ),
          const Divider(),
          if (_profileName.isNotEmpty) ...[
            const ListTile(
              title: Text(
                'Профиль',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.teal),
              title: Text(_profileName),
              subtitle: const Text('Владелец семейного списка'),
            ),
            const Divider(),
          ],
          const ListTile(
            title: Text(
              'О приложении',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.family_restroom, color: Colors.teal),
            title: Text('Volkov Family App'),
            subtitle: Text('Версия 2.0.0'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
