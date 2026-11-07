import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/gift.dart';

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});
  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  List<Gift> _gifts = [];
  @override
  void initState() { super.initState(); _loadGifts(); }

  Future<void> _loadGifts() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('gifts');
    setState(() => _gifts = maps.map((e) => Gift.fromMap(e)).toList());
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    final forWhomController = TextEditingController();
    final categoryController = TextEditingController(text: 'Праздник');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый подарок'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Что подарить?')),
          TextField(controller: forWhomController, decoration: const InputDecoration(labelText: 'Кому?')),
          TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Категория')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('gifts', Gift(title: titleController.text, forWhom: forWhomController.text, category: categoryController.text).toMap());
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
      appBar: AppBar(title: const Text('Подарки')),
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
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: _showAddDialog),
    );
  }
}
