import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'calendar_screen.dart';
import 'add_edit_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = 'Семьянин';
  String? _userPhoto;
  List<Map<String, dynamic>> _todayTasks = [];
  List<Map<String, dynamic>> _upcomingBirthdays = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('categories');
    
    // Получаем дела на сегодня
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final tasks = await db.query('tasks', where: 'due_date = ? AND isCompleted = 0', whereArgs: [todayStr]);
    
    // Получаем ближайшие ДР (сортируем по месяцу/дню)
    final bdays = await db.query('birthdays');
    final sortedBdays = bdays.toList()..sort((a, b) {
      // Простая сортировка по дате (ДД-ММ-ГГГГ)
      return a['date'].toString().compareTo(b['date'].toString());
    });

    setState(() {
      _userName = prefs.getString('my_name') ?? 'Семьянин';
      _userPhoto = prefs.getString('my_photo');
      _todayTasks = tasks;
      _upcomingBirthdays = sortedBdays.take(2).toList();
      _categories = catMaps.map((e) => e['name'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _userName.split(' ').length > 1 ? _userName.split(' ')[1] : _userName;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Шапка с приветствием
              Row(
                children: [
                  if (_userPhoto != null && File(_userPhoto!).existsSync())
                    CircleAvatar(radius: 25, backgroundImage: FileImage(File(_userPhoto!)))
                  else
                    const CircleAvatar(radius: 25, child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Добро пожаловать!', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(firstName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Colors.teal, size: 30),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
                    },
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Ближайшие Дни Рождения
              if (_upcomingBirthdays.isNotEmpty) ...[
                const Text('Ближайшие праздники', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._upcomingBirthdays.map((b) => Card(
                  color: Colors.pink.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.cake, color: Colors.pink),
                    title: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(b['date']),
                    trailing: const Text('🎉', style: TextStyle(fontSize: 20)),
                  ),
                )).toList(),
                const SizedBox(height: 24),
              ],

              // Дела на сегодня
              const Text('Дела на сегодня', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _todayTasks.isEmpty 
                ? const Text('На сегодня дел нет. Отдыхайте! 🎉', style: TextStyle(color: Colors.grey))
                : Column(
                    children: _todayTasks.map((t) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.task, color: Colors.teal),
                        title: Text(t['title']),
                        subtitle: Text('${t['category']} • ${t['periodicity']}'),
                        trailing: Checkbox(
                          value: false,
                          onChanged: (val) {
                            // Можно добавить быстрое выполнение
                          },
                        ),
                      ),
                    )).toList(),
                  ),
              
              const SizedBox(height: 24),

              // Быстрые действия
              const Text('Быстрые действия', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAction(Icons.add_task, 'Дело', () async {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AddEditScreen(type: 'task', categories: _categories),
                    ));
                    if (result == true) _loadData();
                  }),
                  _buildQuickAction(Icons.shopping_cart, 'Покупка', () async {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (context) => AddEditScreen(type: 'purchase', categories: _categories),
                    ));
                    if (result == true) _loadData();
                  }),
                  _buildQuickAction(Icons.note_add, 'Заметка', () {
                    widget.onNavigateToTab(3); // Переход на вкладку Заметок
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.teal.shade100,
            child: Icon(icon, color: Colors.teal),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
