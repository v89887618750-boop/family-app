import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('categories');
    setState(() => _categories = maps.map((e) => e['name'] as String).toList());
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('categories', {'name': controller.text}, conflictAlgorithm: ConflictAlgorithm.ignore);
              if (mounted) Navigator.pop(context);
              _loadCategories();
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String name) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('categories', where: 'name = ?', whereArgs: [name]);
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const ListTile(title: Text('Категории', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ..._categories.map((cat) => ListTile(
                title: Text(cat),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCategory(cat),
                ),
              )),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text('Добавить категорию'),
            onTap: _showAddCategoryDialog,
          ),
          const Divider(),
          const ListTile(title: Text('О приложении', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('Версия'), subtitle: Text('1.0.0')),
        ],
      ),
    );
  }
}
