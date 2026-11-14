import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../db/database_helper.dart';
import '../models/purchase.dart';
import 'add_edit_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with SingleTickerProviderStateMixin {
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
    final catMaps = await db.query('categories', orderBy: 'name ASC');
    final purchaseMaps = await db.query('purchases');

    if (!mounted) return;
    setState(() {
      _categories = catMaps
          .map((e) => e['name'] as String)
          .toList();
      _allPurchases = purchaseMaps.map((e) => Purchase.fromMap(e)).toList();
    });
  }

  /// Открытие покупки на редактирование.
  ///
  /// Раньше экран падал: AddEditScreen обращался к полям, которых у Purchase нет
  /// (dueDate/dueTime/readingValue), а при сохранении пытался записать в таблицу
  /// purchases колонки из tasks. Обе причины устранены (см. add_edit_screen.dart).
  Future<void> _openAddEdit({Purchase? item}) async {
    if (_categories.isEmpty) {
      _showMessage('Сначала добавьте категорию в настройках');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditScreen(
          type: 'purchase',
          item: item,
          categories: _categories,
        ),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _toggle(Purchase item) async {
    final db = await DatabaseHelper.instance.database;
    item.isCompleted = !item.isCompleted;

    // Обновляем только нужное поле — не тащим в UPDATE первичный ключ.
    await db.update(
      'purchases',
      {'isCompleted': item.isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [item.id],
    );

    if (item.isCompleted) {
      _confettiController.play();
      if (item.periodicity == 'Ежегодно') {
        Future.delayed(
          const Duration(milliseconds: 300),
          () => _confettiController.play(),
        );
      }
    }

    await _loadData();
  }

  Future<void> _clearCompleted() async {
    final completed = _allPurchases.where((p) => p.isCompleted).toList();
    if (completed.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить купленное?'),
        content: Text('Будет удалено позиций: ${completed.length}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseHelper.instance.database;
    await db.delete('purchases', where: 'isCompleted = 1');
    await _loadData();
  }

  Future<void> _confirmDelete(Purchase item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Удалить "${item.title}" из списка покупок?'),
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
    await db.delete('purchases', where: 'id = ?', whereArgs: [item.id]);
    await _loadData();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  List<Purchase> _getFilteredPurchases(String filter) {
    final filtered = _allPurchases.where((p) {
      switch (filter) {
        case 'today':
          return p.periodicity == 'Разово' ||
              p.periodicity == 'Ежедневно';
        case 'week':
          return p.periodicity == 'Ежемесячно';
        case 'global':
          return p.periodicity == 'Ежегодно';
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return filtered;
  }

  String _periodicityLabel(String periodicity) {
    switch (periodicity) {
      case 'Разово':
        return 'сегодня';
      case 'Ежедневно':
        return 'каждый день';
      case 'Ежемесячно':
        return 'на неделе';
      case 'Ежегодно':
        return 'глобально';
      default:
        return periodicity;
    }
  }

  Widget _buildPurchaseList(String filter) {
    final items = _getFilteredPurchases(filter);

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  filter == 'today'
                      ? 'В магазин пока ничего не нужно!'
                      : 'Список пуст',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Slidable(
            key: ValueKey('purchase-${item.id}'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.28,
              children: [
                SlidableAction(
                  onPressed: (_) => _confirmDelete(item),
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
                // Тап по строке — открыть редактор покупки.
                onTap: () => _openAddEdit(item: item),
                leading: Checkbox(
                  value: item.isCompleted,
                  onChanged: (_) => _toggle(item),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted ? Colors.grey : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.category} • ${_periodicityLabel(item.periodicity)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (item.note != null && item.note!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.note!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупки'),
        actions: [
          IconButton(
            tooltip: 'Очистить выполненные',
            icon: const Icon(Icons.cleaning_services),
            onPressed: _allPurchases.any((p) => p.isCompleted)
                ? _clearCompleted
                : null,
          ),
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
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildPurchaseList('today'),
              _buildPurchaseList('week'),
              _buildPurchaseList('global'),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
                createParticlePath: drawStar,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
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
    final fullAngle = degToRad(360);

    final path = Path();
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * cos(step - halfWidth),
        halfWidth + externalRadius * sin(step - halfWidth),
      );
      path.lineTo(
        halfWidth + internalRadius * cos(step + halfDegreesPerStep - halfWidth),
        halfWidth + internalRadius * sin(step + halfDegreesPerStep - halfWidth),
      );
    }
    path.close();
    return path;
  }
}
