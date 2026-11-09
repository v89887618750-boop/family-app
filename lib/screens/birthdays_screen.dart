import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/birthday.dart';
import 'gifts_screen.dart'; // Импортируем экран подарков

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
    // ... (код диалога добавления/редактирования ДР остался прежним, я его пропустил для краткости, он у вас уже есть)
  }

  String _getBirthdayStatus(String dateStr) {
    // ... (код подсчета статуса остался прежним)
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // ... (сортировка осталась прежней)

    return Scaffold(
      appBar: AppBar(title: const Text('Дни рождения')),
      body: _birthdays.isEmpty ? const Center(child: Text('Нет записей')) : ListView.builder(
        itemCount: _birthdays.length,
        itemBuilder: (context, index) {
          final bday = _birthdays[index];
          final status = _getBirthdayStatus(bday.date);
          final isSoon = status.contains('Сегодня') || (status.contains('Через') && int.tryParse(status.split(' ')[1])! <= 7);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              onTap: () => _showAddEditDialog(item: bday),
              leading: Icon(Icons.cake, color: isSoon ? Colors.pink : Colors.grey),
              title: Text(bday.name),
              subtitle: Text('${bday.date} • ${bday.category}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: isSoon ? Colors.pink : Colors.teal)),
                  const SizedBox(width: 8),
                  // Кнопка для перехода к подаркам
                  IconButton(
                    icon: const Icon(Icons.card_giftcard, color: Colors.teal),
                    tooltip: 'Список желаний',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GiftsScreen(filterForWhom: bday.name),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => _showAddEditDialog()),
    );
  }
}
