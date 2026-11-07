import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/purchase.dart';
import '../widgets/item_tile.dart';
import 'add_edit_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Purchase> _purchases = [];
  @override
  void initState() { super.initState(); _loadPurchases(); }

  Future<void> _loadPurchases() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('purchases');
    setState(() => _purchases = maps.map((e) => Purchase.fromMap(e)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Покупки')),
      body: _purchases.isEmpty ? const Center(child: Text('Список покупок пуст')) : ListView.builder(
        itemCount: _purchases.length,
        itemBuilder: (context, index) {
          final item = _purchases[index];
          return ItemTile(
            title: item.title,
            subtitle: '${item.category} • ${item.periodicity}',
            isCompleted: item.isCompleted,
            onToggle: () async {
              final db = await DatabaseHelper.instance.database;
              item.isCompleted = !item.isCompleted;
              await db.update('purchases', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
              _loadPurchases();
            },
            onDelete: () async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('purchases', where: 'id = ?', whereArgs: [item.id]);
              _loadPurchases();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditScreen(type: 'purchase')));
          if (result == true) _loadPurchases();
        },
      ),
    );
  }
}
