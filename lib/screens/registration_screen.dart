import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;
  const RegistrationScreen({super.key, required this.onRegistrationComplete});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _surnameController = TextEditingController();
  final _nameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _maidenNameController = TextEditingController();
  String? _photoPath;

  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;

  final List<String> _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  Future<void> _saveProfile() async {
    if (_surnameController.text.trim().isEmpty || 
        _nameController.text.trim().isEmpty || 
        _selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, заполните Фамилию, Имя и Дату рождения')),
      );
      return;
    }

    String fullName = '${_surnameController.text.trim()} ${_nameController.text.trim()}';
    if (_patronymicController.text.trim().isNotEmpty) {
      fullName += ' ${_patronymicController.text.trim()}';
    }

    String formattedDate = '${_selectedDay.toString().padLeft(2, '0')}-${_selectedMonth.toString().padLeft(2, '0')}-$_selectedYear';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_name', fullName);
    await prefs.setString('my_date', formattedDate);
    if (_photoPath != null) await prefs.setString('my_photo', _photoPath!);

    final db = await DatabaseHelper.instance.database;
    
    // 1. Сначала создаем запись в Днях рождения для себя
    int bdayId = await db.insert('birthdays', {
      'name': fullName,
      'date': formattedDate,
      'category': 'Я',
      'remind_days': 1,
      'photo_path': _photoPath,
    });

    // 2. Затем создаем запись в Семье и привязываем к ДР
    await db.insert('family_members', {
      'name': fullName,
      'relation': 'Я',
      'photo_path': _photoPath,
      'birthday_id': bdayId, // <-- ПРИВЯЗКА!
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
            children: [
              const Icon(Icons.family_restroom, size: 80, color: Colors.teal),
              const SizedBox(height: 16),
              const Text('Добро пожаловать!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
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

              Row(
                children: [
                  Expanded(child: TextField(controller: _surnameController, decoration: const InputDecoration(labelText: 'Фамилия', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: _patronymicController, decoration: const InputDecoration(labelText: 'Отчество', border: OutlineInputBorder())),
              
              const SizedBox(height: 24),
              const Text('Дата рождения', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'День', border: OutlineInputBorder()),
                      value: _selectedDay,
                      items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                      onChanged: (v) => setState(() => _selectedDay = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Месяц', border: OutlineInputBorder()),
                      value: _selectedMonth,
                      items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_months[m - 1]))).toList(),
                      onChanged: (v) => setState(() => _selectedMonth = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Год', border: OutlineInputBorder()),
                      value: _selectedYear,
                      items: List.generate(100, (i) => DateTime.now().year - i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (v) => setState(() => _selectedYear = v),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(onPressed: _saveProfile, child: const Text('Создать профиль', style: TextStyle(fontSize: 18))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
