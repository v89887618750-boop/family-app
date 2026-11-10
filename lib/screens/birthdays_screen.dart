import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Добавили для форматирования даты
import '../db/database_helper.dart';
import '../models/birthday.dart';
import 'gifts_screen.dart';

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
    String? photoPath = item?.photoPath;

    // Функция для открытия календаря
    Future<void> pickDate() async {
      DateTime initialDate = DateTime.now();
      // Пытаемся распарсить текущую введенную дату
      if (dateController.text.isNotEmpty) {
        try {
          final parts = dateController.text.replaceAll('.', '-').split('-');
          if (parts.length == 3) {
            initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (e) {}
      }

      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        locale: const Locale('ru', 'RU'), // Русский язык в календаре
      );
      
      if (picked != null) {
        // Форматируем в ДД-ММ-ГГГГ
        String formattedDate = DateFormat('dd-MM-yyyy').format(picked);
        dateController.text = formattedDate;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Новый ДР' : 'Редактировать ДР'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoPath != null) 
                  CircleAvatar(radius: 40, backgroundImage: FileImage(File(photoPath))),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setDialogState(() => photoPath = picked.path);
                  },
                  icon: const Icon(Icons.photo_camera), 
                  label: const Text('Выбрать аватарку'),
                ),
                const SizedBox(height: 8),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
                
                // Поле ввода даты с кнопкой календаря
                TextField(
                  controller: dateController, 
                  decoration: InputDecoration(
                    labelText: 'Дата рождения',
                    hintText: 'ДД-ММ-ГГГГ',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month, color: Colors.teal),
                      onPressed: pickDate,
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  onTap: () {
                    // При нажатии на поле тоже открываем календарь
                    pickDate();
                  },
                ),
                
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
                String cleanName = nameController.text.trim();
                // Меняем точки на дефисы на случай, если ввели вручную
                String cleanDate = dateController.text.trim().replaceAll('.', '-');

                if (cleanName.isEmpty || cleanDate.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пожалуйста, заполните Имя и Дату')),
                  );
                  return;
                }
                
                // Простая проверка на формат
                final parts = cleanDate.split('-');
                if (parts.length != 3) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Дата должна быть в формате ДД-ММ-ГГГГ')),
                  );
                  return;
                }

                final db = await DatabaseHelper.instance.database;
                final bday = Birthday(
                  name: cleanName, 
                  date: cleanDate, 
                  category: 'Семья', 
                  remindDays: remindDays,
                  photoPath: photoPath
                );
                
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

  String _getBirthdayStatus(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return 'Неверный формат';
      final now = DateTime.now();
      DateTime nextBday = DateTime(now.year, int.parse(parts[1]), int.parse(parts[0]));
      
      if (nextBday.isBefore(DateTime(now.year, now.month, now.day))) {
        nextBday = DateTime(now.year + 1, nextBday.month, nextBday.day);
      }
      
      int age = nextBday.year - int.parse(parts[2]);
      final diff = nextBday.difference(DateTime(now.year, now.month, now.day)).inDays;
      
      if (diff == 0) return '🎉 Сегодня ($age лет)!';
      return 'Через $diff дн. ($age лет)';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
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

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              onTap: () => _showAddEditDialog(item: bday),
              leading: bday.photoPath != null && File(bday.photoPath!).existsSync()
                  ? CircleAvatar(backgroundImage: FileImage(File(bday.photoPath!))) 
                  : Icon(Icons.cake, color: isSoon ? Colors.pink : Colors.grey), 
              title: Text(bday.name),
              subtitle: Text('${bday.date} • ${bday.category}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: isSoon ? Colors.pink : Colors.teal)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.card_giftcard, color: Colors.teal),
                    tooltip: 'Список желаний',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GiftsScreen(
                            filterForWhom: bday.name,
                            avatarPath: bday.photoPath,
                          ),
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add), 
        onPressed: () => _showAddEditDialog(), 
      ),
    );
  }
}
