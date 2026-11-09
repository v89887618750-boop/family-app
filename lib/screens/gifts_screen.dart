import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/gift.dart';
import 'add_edit_screen.dart'; // Мы не будем использовать этот экран для подарков, сделаем свой диалог

class GiftsScreen extends StatefulWidget {
  final String? filterForWhom; // Фильтр: если передано имя, показываем только его подарки

  const GiftsScreen({super.key, this.filterForWhom});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  List<Gift> _gifts = [];

  @override
  void initState() { super.initState(); _loadGifts(); }

  Future<void> _loadGifts() async {
    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> maps;
    if (widget.filterForWhom != null) {
      maps = await db.query('gifts', where: 'forWhom = ?', whereArgs: [widget.filterForWhom]);
    } else {
      maps = await db.query('gifts');
    }
    setState(() => _gifts = maps.map((e) => Gift.fromMap(e)).toList());
  }

  void _showAddEditDialog({Gift? item}) {
    final titleController = TextEditingController(text: item?.title ?? '');
    final forWhomController = TextEditingController(text: item?.forWhom ?? widget.filterForWhom ?? '');
    final categoryController = TextEditingController(text: item?.category ?? 'Праздник');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Новый подарок' : 'Редактировать'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Что подарить?')),
            TextField(controller: forWhomController, decoration: const InputDecoration(labelText: 'Кому?'), readOnly: widget.filterForWhom != null),
            TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Категория')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || forWhomController.text.isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              final gift = Gift(title: titleController.text, forWhom: forWhomController.text, category: categoryController.text, isBought: item?.isBought ?? false);
              
              if (item == null) {
                await db.insert('gifts', gift.toMap());
              } else {
                await db.update('gifts', gift.toMap(), where: 'id = ?', whereArgs: [item.id]);
              }
              if (mounted) Navigator.pop(context);
              _loadGifts();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.filterForWhom != null ? 'Подарки для ${widget.filterForWhom}' : 'Подарки')),
      body: _gifts.isEmpty ? const Center(child: Text('Список подарков пуст')) : ListView.builder(
        itemCount: _gifts.length,
        itemBuilder: (context, index) {
          final gift = _gifts[index];
          return Dismissible(
            key: Key(gift.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('gifts', where: 'id = ?', whereArgs: [gift.id]);
              _loadGifts();
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                onTap: () => _showAddEditDialog(item: gift),
                leading: Checkbox(
                  value: gift.isBought,
                  onChanged: (_) async {
                    final db = await DatabaseHelper.instance.database;
                    gift.isBought = !gift.isBought;
                    await db.update('gifts', gift.toMap(), where: 'id = ?', whereArgs: [gift.id]);
                    _loadGifts();
                  },
                ),
                title: Text(gift.title, style: TextStyle(decoration: gift.isBought ? TextDecoration.lineThrough : null, color: gift.isBought ? Colors.grey : null)),
                subtitle: Text('Для: ${gift.forWhom} • ${gift.category}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => _showAddEditDialog()),
    );
  }
}
