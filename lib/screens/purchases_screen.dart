import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  late ConfettiController _confettiController;

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 3, vsync: this); 
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
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

  Future<void> _confirmDelete(Purchase item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Удалить "${item.title}" из списка покупок?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('purchases', where: 'id = ?', whereArgs: [item.id]);
      _loadData();
    }
  }

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
        return Slidable(
          key: Key(item.id.toString()),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (context) => _confirmDelete(item), 
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Удалить',
                borderRadius: BorderRadius.circular(12),
              ),
            ],
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              // <-- ИСПРАВЛЕНО: привязка к открытию редактора
              onTap: () => _openAddEdit(item: item), 
              leading: Checkbox(
                value: item.isCompleted,
                onChanged: (_) async {
                  final db = await DatabaseHelper.instance.database;
                  item.isCompleted = !item.isCompleted;
                  await db.update('purchases', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
                  if (item.isCompleted) {
                    if (item.periodicity == 'Ежегодно') {
                      _confettiController.play();
                      Future.delayed(const Duration(milliseconds: 300), () => _confettiController.play());
                    } else {
                      _confettiController.play();
                    }
                  }
                  _loadData();
                },
              ),
              title: Text(item.title, style: TextStyle(decoration: item.isCompleted ? TextDecoration.lineThrough : null, color: item.isCompleted ? Colors.grey : null)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.category),
                  if (item.note != null && item.note!.isNotEmpty)
                    Text(item.note!, style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
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
            onPressed: _allPurchases.any((p) => p.isCompleted) ? _clearCompleted : null,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'В магазин'), Tab(text: 'На неделе'), Tab(text: 'Глобальные')],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [_buildPurchaseList('today'), _buildPurchaseList('week'), _buildPurchaseList('global')],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
              createParticlePath: drawStar,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => _openAddEdit()),
    );
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step - halfWidth), halfWidth + externalRadius * sin(step - halfWidth));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep - halfWidth), halfWidth + internalRadius * sin(step + halfDegreesPerStep - halfWidth));
    }
    path.close();
    return path;
  }
}
