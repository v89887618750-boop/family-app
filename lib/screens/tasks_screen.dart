import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../widgets/item_tile.dart';
import 'add_edit_screen.dart';
import 'meter_stats_screen.dart'; // Импортируем экран статистики

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  List<Task> _allTasks = [];
  List<String> _categories = [];
  late TabController _tabController;

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 4, vsync: this); // 4 вкладки
    _loadData(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('categories');
    final taskMaps = await db.query('tasks');
    setState(() {
      _categories = catMaps.map((e) => e['name'] as String).toList();
      _allTasks = taskMaps.map((e) => Task.fromMap(e)).toList();
    });
  }

  Future<void> _openAddEdit({Task? task}) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала добавьте категорию в настройках')));
      return;
    }
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (context) => AddEditScreen(type: 'task', item: task, categories: _categories),
    ));
    if (result == true) _loadData();
  }

  Future<void> _clearCompleted() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('tasks', where: 'isCompleted = 1');
    _loadData();
  }

  // Фильтрация задач
  List<Task> _getFilteredTasks(String filter) {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final nextWeek = now.add(const Duration(days: 7));

    List<Task> filtered = _allTasks.where((t) {
      if (filter == 'today') {
        if (t.isCompleted) return false;
        if (t.periodicity == 'Ежедневно') return true;
        
        if (t.dueDate != null) {
           final due = DateTime.parse(t.dueDate!);
           final today = DateTime.now();
           final diff = due.difference(DateTime(today.year, today.month, today.day)).inDays;
           
           if (t.readingValue != null) {
             // Если это счетчик, показываем за 2 дня до подачи
             if (diff <= 2 && diff >= 0) return true; 
           } else {
             if (diff == 0) return true;
           }
        }
        return false;
      } else if (filter == 'week') {
        if (t.isCompleted) return false;
        if (t.periodicity == 'Ежедневно') return false; 
        if (t.dueDate != null) {
          final due = DateTime.parse(t.dueDate!);
          if (due.isAfter(now) && due.isBefore(nextWeek)) return true;
        }
        return false;
      } else if (filter == 'regular') {
        if (t.periodicity == 'Ежедневно' || t.periodicity == 'Ежемесячно' || t.periodicity == 'Ежегодно') return true;
        return false;
      }
      return true; 
    }).toList();

    filtered.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      return a.title.compareTo(b.title);
    });

    return filtered;
  }

  Widget _buildTaskList(String filter) {
    final tasks = _getFilteredTasks(filter);
    if (tasks.isEmpty) {
      return Center(child: Text(filter == 'today' ? 'На сегодня дел нет! 🎉' : 'Нет дел'));
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        bool isOverdue = false;
        if (!task.isCompleted && task.dueDate != null) {
          final due = DateTime.parse(task.dueDate!);
          final today = DateTime.now();
          if (due.isBefore(DateTime(today.year, today.month, today.day))) isOverdue = true;
        }

        String subtitle = '${task.category} • ${task.periodicity}';
        if (task.dueDate != null) {
          subtitle += " • до ${task.dueDate!.split('-').reversed.join('.')}";
        }

        return ItemTile(
          title: task.title,
          subtitle: subtitle,
          isCompleted: task.isCompleted,
          isOverdue: isOverdue,
          readingValue: task.readingValue, // Передаем показания
          onShowStats: task.readingValue != null ? () {
            // Переход на экран статистики
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MeterStatsScreen(taskId: task.id!, taskTitle: task.title),
              ),
            );
          } : null,
          onToggle: () async {
            final db = await DatabaseHelper.instance.database;
            task.isCompleted = !task.isCompleted;
            await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
            _loadData();
          },
          onEdit: () => _openAddEdit(task: task),
          onDelete: () async {
            final db = await DatabaseHelper.instance.database;
            await db.delete('tasks', where: 'id = ?', whereArgs: [task.id]);
            _loadData();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список дел'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Очистить выполненные',
            onPressed: _allTasks.any((t) => t.isCompleted) ? _clearCompleted : null,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Сегодня'),
            Tab(text: 'На неделе'),
            Tab(text: 'Регулярные'),
            Tab(text: 'Все'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList('today'),
          _buildTaskList('week'),
          _buildTaskList('regular'),
          _buildTaskList('all'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _openAddEdit(),
      ),
    );
  }
}
