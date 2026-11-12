import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // Данные для календаря
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _birthdays = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final tasks = await db.query('tasks');
    final bdays = await db.query('birthdays');
    setState(() {
      _tasks = tasks;
      _birthdays = bdays;
    });
  }

  // Получить количество дней в месяце
  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  // Получить первый день недели месяца (0 - Пн, 6 - Вс)
  int _getFirstWeekday(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday - 1;
  }

  // Проверка, есть ли события в этот день
  bool _hasEvents(int day) {
    String dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    
    // Проверяем задачи
    bool hasTask = _tasks.any((t) => t['due_date'] == dateStr);
    // Проверяем ДР (формат в базе ДД-ММ-ГГГГ)
    String bdayStr = '${day.toString().padLeft(2, '0')}-${_currentMonth.month.toString().padLeft(2, '0')}';
    bool hasBday = _birthdays.any((b) => b['date'].toString().startsWith(bdayStr));

    return hasTask || hasBday;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstWeekday = _getFirstWeekday(_currentMonth);
    
    // События на выбранный день
    String selectedDateStr = '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';
    String selectedBdayStr = '${_selectedDay.day.toString().padLeft(2, '0')}-${_selectedDay.month.toString().padLeft(2, '0')}';
    
    final selectedTasks = _tasks.where((t) => t['due_date'] == selectedDateStr).toList();
    final selectedBdays = _birthdays.where((b) => b['date'].toString().startsWith(selectedBdayStr)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Семейный календарь')),
      body: Column(
        children: [
          // Шапка календаря (Месяц и стрелки)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1)),
                ),
                Text(
                  '${_currentMonth.month.toString().padLeft(2, '0')}.${_currentMonth.year}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1)),
                ),
              ],
            ),
          ),
          
          // Дни недели
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Пн', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('Вт', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('Ср', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('Чт', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('Пт', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('Сб', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              Text('Вс', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          
          // Сетка чисел
          Expanded(
            flex: 2,
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: daysInMonth + firstWeekday,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink(); // Пустые клетки в начале
                
                final day = index - firstWeekday + 1;
                final isToday = DateTime.now().day == day && DateTime.now().month == _currentMonth.month && DateTime.now().year == _currentMonth.year;
                final isSelected = _selectedDay.day == day && _selectedDay.month == _currentMonth.month && _selectedDay.year == _currentMonth.year;
                final hasEvents = _hasEvents(day);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = DateTime(_currentMonth.year, _currentMonth.month, day);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.teal : (isToday ? Colors.teal.shade100 : null),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : null,
                          ),
                        ),
                        if (hasEvents)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.teal,
                              shape: BoxShape.circle,
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const Divider(),
          
          // Список событий на выбранный день
          Expanded(
            flex: 1,
            child: (selectedTasks.isEmpty && selectedBdays.isEmpty)
                ? const Center(child: Text('На этот день событий нет'))
                : ListView(
                    children: [
                      ...selectedBdays.map((b) => ListTile(
                        leading: const Icon(Icons.cake, color: Colors.pink),
                        title: Text('День рождения: ${b['name']}'),
                        subtitle: const Text('🎂 Не забудьте поздравить!'),
                      )),
                      ...selectedTasks.map((t) => ListTile(
                        leading: const Icon(Icons.task, color: Colors.teal),
                        title: Text(t['title']),
                        subtitle: Text('${t['category']} • ${t['periodicity']}'),
                      )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
