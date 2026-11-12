import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../widgets/item_tile.dart';
import '../utils/family_manager.dart'; // Импортируем менеджер семьи
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
  late ConfettiController _confettiController;
  String _familyId = ''; // ID текущей семьи

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 4, vsync: this); 
    _confettiController = ConfettiController(duration: const Duration(seconds: 2)); 
    _initFamily();
  }

  Future<void> _initFamily() async {
    _familyId = await FamilyManager.getFamilyId();
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
    // Загружаем категории и задачи ТОЛЬКО для текущей семьи
    final catMaps = await db.query('categories', where: 'family_id = ?', whereArgs: [_familyId]);
    final taskMaps = await db.query('tasks', where: 'family_id = ?', whereArgs: [_familyId]);
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
    await db.delete('tasks', where: 'isCompleted = 1 AND family_id = ?', whereArgs: [_familyId]);
    _loadData();
  }

  List<Task> _getFilteredTasks(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    List<Task> filtered = _allTasks.where((t) {
      if (filter != 'all' && filter != 'regular' && t.isCompleted) {
        return false;
      }

      if (filter == 'today') {
        if (t.periodicity == 'Ежедневно') return true;
        if (t.dueDate != null) {
           final due = DateTime.parse(t.dueDate!);
           if (due.year == today.year && due.month == today.month && due.day == today.day) return true;
           
           if (t.readingValue != null) {
             final diff = due.difference(today).inDays;
             if (diff >= 0 && diff <= 2) return true; 
           }
        }
        return false;
      } 
      else if (filter == 'week') {
        if (t.periodicity == 'Ежедневно') return false; 
        if (t.dueDate != null) {
          final due = DateTime.parse(t.dueDate!);
          return due.isAfter(today.subtract(const Duration(days: 1))) && due.isBefore(nextWeek);
        }
        return false;
      } 
      else if (filter == 'regular') {
        return t.periodicity == 'Ежедневно' || t.periodicity == 'Ежемесячно' || t.periodicity == 'Ежегодно';
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
        if (task.dueTime != null) {
          subtitle += " в ${task.dueTime}"; 
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
            
            if (task.isCompleted) {
              DateTime now = DateTime.now();
              
              if (task.periodicity == 'Ежедневно') {
                DateTime nextDue = now.add(const Duration(days: 1));
                task.dueDate = nextDue.toIso8601String().split('T')[0];
                task.isCompleted = false; 
              } 
              else if (task.periodicity == 'Ежемесячно' && task.dueDate != null) {
                DateTime due = DateTime.parse(task.dueDate!);
                DateTime nextDue = DateTime(due.year, due.month + 1, due.day);
                task.dueDate = nextDue.toIso8601String().split('T')[0];
                task.isCompleted = false; 
              }
              else if (task.periodicity == 'Ежегодно' && task.dueDate != null) {
                DateTime due = DateTime.parse(task.dueDate!);
                DateTime nextDue = DateTime(due.year + 1, due.month, due.day);
                task.dueDate = nextDue.toIso8601String().split('T')[0];
                task.isCompleted = false; 
              }
            }

            await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
            
            if (task.isCompleted) {
              if (task.readingValue != null) {
                _confettiController.play();
                Future.delayed(const Duration(milliseconds: 300), () => _confettiController.play());
              } else {
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
      path.lineTo(halfWidth + externalRadius * cos(step - halfWidth), halfWidth + externalRadius * sin(step - halfWidth));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep - halfWidth), halfWidth + internalRadius * sin(step + halfDegreesPerStep - halfWidth));
    }
    path.close();
    return path;
  }
}
