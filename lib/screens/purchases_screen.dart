import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/purchase.dart';
import 'add_edit_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> with SingleTickerProviderStateMixin {
  List<Purchase> _allPurchases = [];
  List<String> _categories = [];
  late TabController _tabController;

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 3, vsync: this); // 3 вкладки
    _loadData(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('categories');
    final pMaps = await db.query('purchases');
    setState(() {
      _categories = catMaps.map((e) => e['name'] as String).toList();
      _allPurchases = pMaps.map((e) => Purchase.fromMap(e)).toList();
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

  // Фильтрация по вкладкам
  List<Purchase> _getFilteredPurchases(String filter) {
    List<Purchase> filtered = _allPurchases.where((p) {
      if (filter == 'today') {
        return p.periodicity == 'Разово' || p.periodicity == 'Ежедневно';
      } else if (filter == 'week') {
        return p.periodicity == 'Ежемесячно';
      } else if (filter == 'global') {
        return p.periodicity == 'Ежегодно';
      }
      return true;
    }).toList();

    // Сначала невыполненные, потом выполненные
    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.title.compareTo(b.title);
    });

    return filtered;
  }

  Widget _buildPurchaseList(String filter) {
    final items = _getFilteredPurchases(filter);
    if (items.isEmpty) {
      return Center(child: Text(filter == 'today' ? 'В магазин пока ничего не нужно!' : 'Список пуст'));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
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
              onTap: () => _openAddEdit(item: item),
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
              subtitle: Text(item.category),
            ),
          ),
        );
      },
    );
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
            onPressed: _allPurchases.any((p) => p.isCompleted) ? _clearCompleted : null,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'В магазин'),
            Tab(text: 'На неделе'),
            Tab(text: 'Глобальные'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPurchaseList('today'),
          _buildPurchaseList('week'),
          _buildPurchaseList('global'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _openAddEdit(),
      ),
    );
  }
}
