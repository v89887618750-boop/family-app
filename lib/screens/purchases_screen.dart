import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/purchase.dart';
import 'add_edit_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Purchase> _purchases = [];
  List<String> _categories = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('categories');
    final maps = await db.query('purchases');
    setState(() {
      _categories = catMaps.map((e) => e['name'] as String).toList();
      _purchases = maps.map((e) => Purchase.fromMap(e)).toList();
    });
  }

  Future<void> _openAddEdit({Purchase? item}) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала добавьте категорию в настройках')));
      return;
    }
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (context) => AddEditScreen(type: 'purchase', item: item, categories: _categories),
    ));
    if (result == true) _loadData();
  }

  Future<void> _clearCompleted() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('purchases', where: 'isCompleted = 1');
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Очистить купленное',
            onPressed: _purchases.any((p) => p.isCompleted) ? _clearCompleted : null,
          )
        ],
      ),
      body: _purchases.isEmpty ? const Center(child: Text('Список покупок пуст')) : ListView.builder(
        itemCount: _purchases.length,
        itemBuilder: (context, index) {
          final item = _purchases[index];
          return Dismissible(
            key: Key(item.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('purchases', where: 'id = ?', whereArgs: [item.id]);
              _loadData();
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                onTap: () => _openAddEdit(item: item), // Нажатие для редактирования
                leading: Checkbox(
                  value: item.isCompleted,
                  onChanged: (_) async {
                    final db = await DatabaseHelper.instance.database;
                    item.isCompleted = !item.isCompleted;
                    await db.update('purchases', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
                    _loadData();
                  },
                ),
                title: Text(item.title, style: TextStyle(decoration: item.isCompleted ? TextDecoration.lineThrough : null, color: item.isCompleted ? Colors.grey : null)),
                subtitle: Text('${item.category} • ${item.periodicity}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _openAddEdit(),
      ),
    );
  }
}
