import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;
  const RegistrationScreen({super.key, required this.onRegistrationComplete});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  String? _photoPath;

  Future<void> _pickDate() async {
    // Скрываем клавиатуру, чтобы не мешала календарю
    FocusScope.of(context).unfocus();
    
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 25));
    if (_dateController.text.isNotEmpty) {
      try {
        final parts = _dateController.text.split('-');
        if (parts.length == 3) initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } catch (e) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() => _dateController.text = DateFormat('dd-MM-yyyy').format(picked));
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty || _dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, заполните имя и дату рождения')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_name', _nameController.text.trim());
    await prefs.setString('my_date', _dateController.text.trim());
    if (_photoPath != null) await prefs.setString('my_photo', _photoPath!);

    final db = await DatabaseHelper.instance.database;
    await db.insert('family_members', {
      'name': _nameController.text.trim(),
      'relation': 'Я',
      'photo_path': _photoPath,
    });

    widget.onRegistrationComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.family_restroom, size: 80, color: Colors.teal),
              const SizedBox(height: 16),
              const Text(
                'Добро пожаловать!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Давайте создадим ваш профиль для семейного древа',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              // Аватарка
              GestureDetector(
                onTap: () async {
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (picked != null) setState(() => _photoPath = picked.path);
                },
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.teal.shade100,
                  backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                  child: _photoPath == null ? const Icon(Icons.add_a_photo, size: 30, color: Colors.teal) : null,
                ),
              ),
              const SizedBox(height: 24),

              // Поля ввода
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Ваше Имя и Фамилия', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              
              // ИСПРАВЛЕННОЕ ПОЛЕ ДАТЫ
              GestureDetector(
                onTap: _pickDate, // Вызываем календарь при нажатии на всю область
                child: AbsorbPointer( // Блокируем ввод с клавиатуры, чтобы не было конфликтов
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Дата рождения',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today), // Иконка календаря для красоты
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Создать профиль', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
