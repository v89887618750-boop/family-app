import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import 'add_edit_screen.dart';
import 'calendar_screen.dart';

/// Главный экран: приветствие, ближайшие праздники, дела на сегодня
/// и быстрые действия.
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
  List<_BirthdayItem> _upcomingBirthdays = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseHelper.instance.database;

    final catMaps = await db.query('categories', orderBy: 'name ASC');

    final now = DateTime.now();
    final todayStr = _isoDate(now);
    final taskMaps = await db.query(
      'tasks',
      where: 'isCompleted = 0 AND (due_date = ? OR periodicity = ?)',
      whereArgs: [todayStr, 'Ежедневно'],
    );

    final bdayMaps = await db.query('birthdays');

    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('my_name') ?? 'Семьянин';
      _userPhoto = prefs.getString('my_photo');
      _todayTasks = taskMaps;
      _categories = catMaps.map((e) => e['name'] as String).toList();
      _upcomingBirthdays = _buildUpcomingBirthdays(bdayMaps);
    });
  }

  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Считает, когда будет ближайший день рождения, и сортирует по близости.
  List<_BirthdayItem> _buildUpcomingBirthdays(
    List<Map<String, dynamic>> maps,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <_BirthdayItem>[];

    for (final map in maps) {
      final parsed = _parseDate(map['date'] as String?);
      if (parsed == null) continue;

      var next = DateTime(now.year, parsed.month, parsed.day);
      if (next.isBefore(today)) {
        next = DateTime(now.year + 1, parsed.month, parsed.day);
      }

      items.add(
        _BirthdayItem(
          name: (map['name'] as String?) ?? '',
          date: parsed,
          daysLeft: next.difference(today).inDays,
        ),
      );
    }

    items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return items.take(2).toList();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.trim().split(RegExp(r'[-./]'));
    if (parts.length != 3) return null;

    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;

    final int day;
    final int month;
    final int year;
    if (parts[0].length == 4) {
      year = first;
      month = second;
      day = third;
    } else {
      day = first;
      month = second;
      year = third;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month || date.year != year) return null;
    return date;
  }

  Future<void> _completeTask(Map<String, dynamic> task) async {
    final id = task['id'];
    if (id == null) return;
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'tasks',
      {'isCompleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadData();
  }

  Future<void> _openAddEdit(String type) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте категорию в настройках')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditScreen(type: type, categories: _categories),
      ),
    );
    if (result == true) {
      await _loadData();
    }
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = _userName.trim().split(RegExp(r'\s+'));
    final firstName = parts.length > 1 ? parts[1] : _userName;
    final hasPhoto = _userPhoto != null && File(_userPhoto!).existsSync();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Шапка с приветствием
              Row(
                children: [
                  if (hasPhoto)
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: FileImage(File(_userPhoto!)),
                    )
                  else
                    const CircleAvatar(
                      radius: 25,
                      child: Icon(Icons.person),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Добро пожаловать!',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          firstName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Календарь',
                    icon: const Icon(
                      Icons.calendar_month,
                      color: Colors.teal,
                      size: 30,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalendarScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Ближайшие дни рождения
              if (_upcomingBirthdays.isNotEmpty) ...[
                const Text(
                  'Ближайшие праздники',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._upcomingBirthdays.map(
                  (item) => Card(
                    color: Colors.pink.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.cake, color: Colors.pink),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item.formattedDate} • ${item.daysLeftText}',
                      ),
                      trailing: const Text('🎉', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Дела на сегодня
              const Text(
                'Дела на сегодня',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_todayTasks.isEmpty)
                const Text(
                  'На сегодня дел нет. Отдыхайте! 🎉',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ..._todayTasks.map(
                  (task) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.task, color: Colors.teal),
                      title: Text((task['title'] as String?) ?? ''),
                      subtitle: Text(
                        '${task['category'] ?? ''} • ${task['periodicity'] ?? ''}',
                      ),
                      trailing: Checkbox(
                        value: false,
                        onChanged: (_) => _completeTask(task),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Быстрые действия
              const Text(
                'Быстрые действия',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickAction(
                    Icons.add_task,
                    'Дело',
                    () => _openAddEdit('task'),
                  ),
                  _buildQuickAction(
                    Icons.shopping_cart,
                    'Покупка',
                    () => _openAddEdit('purchase'),
                  ),
                  _buildQuickAction(
                    Icons.note_add,
                    'Заметка',
                    // Заметки — это вкладка №4 (0: Главная, 1: Дела,
                    // 2: Покупки, 3: Семья, 4: Заметки, 5: Настройки).
                    () => widget.onNavigateToTab(4),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthdayItem {
  final String name;
  final DateTime date;
  final int daysLeft;

  _BirthdayItem({
    required this.name,
    required this.date,
    required this.daysLeft,
  });

  String get formattedDate {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String get daysLeftText {
    if (daysLeft == 0) return 'Сегодня!';
    if (daysLeft == 1) return 'Завтра';
    final mod100 = daysLeft % 100;
    final mod10 = daysLeft % 10;
    String word = 'дней';
    if (mod100 < 11 || mod100 > 14) {
      if (mod10 == 1) {
        word = 'день';
      } else if (mod10 >= 2 && mod10 <= 4) {
        word = 'дня';
      }
    }
    return 'через $daysLeft $word';
  }
}
