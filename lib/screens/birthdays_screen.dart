import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/birthday.dart';

class BirthdaysScreen extends StatefulWidget {
  const BirthdaysScreen({super.key});
  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
  List<Birthday> _birthdays = [];
  @override
  void initState() { super.initState(); _loadBirthdays(); }

  Future<void> _loadBirthdays() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('birthdays');
    setState(() => _birthdays = maps.map((e) => Birthday.fromMap(e)).toList());
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final dateController = TextEditingController();
    final categoryController = TextEditingController(text: 'Семья');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый день рождения'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
          TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Дата (ММ-ДД)')),
          TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Категория')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || dateController.text.isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('birthdays', Birthday(name: nameController.text, date: dateController.text, category: categoryController.text).toMap());
              if (mounted) Navigator.pop(context);
              _loadBirthdays();
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
      appBar: AppBar(title: const Text('Дни рождения')),
      body: _birthdays.isEmpty ? const Center(child: Text('Нет записей')) : ListView.builder(
        itemCount: _birthdays.length,
        itemBuilder: (context, index) {
          final bday = _birthdays[index];
          return Dismissible(
            key: Key(bday.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            onDismissed: (_) async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('birthdays', where: 'id = ?', whereArgs: [bday.id]);
              _loadBirthdays();
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.cake, color: Colors.pink),
                title: Text(bday.name),
                subtitle: Text('Дата: ${bday.date} • ${bday.category}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: _showAddDialog),
    );
  }
}
