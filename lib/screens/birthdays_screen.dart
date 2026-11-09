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
    final maps = await db.query('birthdays');
    setState(() => _birthdays = maps.map((e) => Birthday.fromMap(e)).toList());
  }

  void _showAddEditDialog({Birthday? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final dateController = TextEditingController(text: item?.date ?? '');
    int remindDays = item?.remindDays ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Новый ДР' : 'Редактировать ДР'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
                TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Дата (ДД-ММ-ГГГГ)', hintText: 'Например: 18-01-1991')),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: remindDays,
                  decoration: const InputDecoration(labelText: 'Напомнить за (дней)'),
                  items: [1, 2, 3, 5, 7].map((d) => DropdownMenuItem(value: d, child: Text('$d дн.'))).toList(),
                  onChanged: (v) => setDialogState(() => remindDays = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || dateController.text.isEmpty) return;
                final db = await DatabaseHelper.instance.database;
                final bday = Birthday(name: nameController.text, date: dateController.text, category: 'Семья', remindDays: remindDays);
                
                if (item == null) {
                  await db.insert('birthdays', bday.toMap());
                } else {
                  await db.update('birthdays', bday.toMap(), where: 'id = ?', whereArgs: [item.id]);
                }
                if (mounted) Navigator.pop(context);
                _loadBirthdays();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  // Вычисляем возраст и сколько дней осталось
  String _getBirthdayStatus(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return 'Неверный формат';
      final now = DateTime.now();
      DateTime bdayDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      
      int age = now.year - bdayDate.year;
      
      if (bdayDate.month < now.month || (bdayDate.month == now.month && bdayDate.day < now.day)) {
        age--; // ДР еще не было в этом году
        bdayDate = DateTime(now.year + 1, bdayDate.month, bdayDate.day);
      } else {
        bdayDate = DateTime(now.year, bdayDate.month, bdayDate.day);
      }
      
      final diff = bdayDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 0) return '🎉 Сегодня ($age лет)!';
      return 'Через $diff дн. ($age лет)';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Сортируем, чтобы ближайшие были сверху
    _birthdays.sort((a, b) {
      final partsA = a.date.split('-');
      final partsB = b.date.split('-');
      if (partsA.length != 3 || partsB.length != 3) return 0;
      
      final now = DateTime.now();
      DateTime dateA = DateTime(now.year, int.parse(partsA[1]), int.parse(partsA[0]));
      DateTime dateB = DateTime(now.year, int.parse(partsB[1]), int.parse(partsB[0]));
      
      if (dateA.isBefore(DateTime(now.year, now.month, now.day))) dateA = DateTime(now.year + 1, dateA.month, dateA.day);
      if (dateB.isBefore(DateTime(now.year, now.month, now.day))) dateB = DateTime(now.year + 1, dateB.month, dateB.day);
      
      return dateA.compareTo(dateB);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Дни рождения')),
      body: _birthdays.isEmpty ? const Center(child: Text('Нет записей')) : ListView.builder(
        itemCount: _birthdays.length,
        itemBuilder: (context, index) {
          final bday = _birthdays[index];
          final status = _getBirthdayStatus(bday.date);
          final isSoon = status.contains('Сегодня') || (status.contains('Через') && int.tryParse(status.split(' ')[1])! <= 7);

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
                onTap: () => _showAddEditDialog(item: bday),
                leading: Icon(Icons.cake, color: isSoon ? Colors.pink : Colors.grey),
                title: Text(bday.name),
                subtitle: Text('${bday.date} • ${bday.category}'),
                trailing: Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: isSoon ? Colors.pink : Colors.teal)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => _showAddEditDialog()),
    );
  }
}
