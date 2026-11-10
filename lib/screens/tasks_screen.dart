import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../widgets/item_tile.dart';
import 'add_edit_screen.dart';
import 'meter_stats_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  List<Task> _allTasks = [];
  List<String> _categories = [];
  late TabController _tabController;
  
  // Контроллер для салюта
  late ConfettiController _confettiController;

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 4, vsync: this); 
    _confettiController = ConfettiController(duration: const Duration(seconds: 2)); // Салют на 2 секунды
    _loadData(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
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
          readingValue: task.readingValue,
          onShowStats: task.readingValue != null ? () {
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
            
            // ЗАПУСК САЛЮТА при выполнении дела
            if (task.isCompleted) {
              if (task.readingValue != null) {
                // Двойной салют для счетчиков (важное событие!)
                _confettiController.play();
                Future.delayed(const Duration(milliseconds: 300), () => _confettiController.play());
              } else {
                // Обычный салют для дел
                _confettiController.play();
              }
            }
            
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
            Tab(text: 'Все'),          
            Tab(text: 'Сегодня'),      
            Tab(text: 'На неделе'),    
            Tab(text: 'Регулярные'),   
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList('all'),      
              _buildTaskList('today'),    
              _buildTaskList('week'),
              _buildTaskList('regular'),
            ],
          ),
          // Слой для салюта
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
              createParticlePath: drawStar,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _openAddEdit(),
      ),
    );
  }

  // Функция для рисования звездочек
  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step - halfWidth),
          halfWidth + externalRadius * sin(step - halfWidth));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep - halfWidth),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep - halfWidth));
    }
    path.close();
    return path;
  }
}
