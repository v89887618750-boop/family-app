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
  void initState() { super.initState(); _loadCategories(); }

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
            value: false, 
            onChanged: (val) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тёмная тема появится в следующем обновлении!')));
            },
          ),
          const Divider(),
          const ListTile(title: Text('Категории (Дом, Работа и т.д.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ..._categories.map((cat) => ListTile(
                title: Text(cat),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final db = await DatabaseHelper.instance.database;
                    await db.delete('categories', where: 'name = ?', whereArgs: [cat]);
                    _loadCategories();
                  },
                ),
              )),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text('Добавить категорию'),
            onTap: _showAddCategoryDialog,
          ),
          const Divider(),
          const ListTile(title: Text('О приложении', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const ListTile(
            leading: Icon(Icons.family_restroom, color: Colors.teal), 
            title: Text('Volkov Family App'), 
            subtitle: Text('Версия 2.0.0'),
          ),
        ],
      ),
    );
  }
}
