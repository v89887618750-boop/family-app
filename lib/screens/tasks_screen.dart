import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../widgets/item_tile.dart';
import 'add_edit_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> _tasks = [];
  List<String> _categories = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final catMaps = await db.query('categories');
    final taskMaps = await db.query('tasks');
    setState(() {
      _categories = catMaps.map((e) => e['name'] as String).toList();
      _tasks = taskMaps.map((e) => Task.fromMap(e)).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список дел'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Очистить выполненные',
            onPressed: _tasks.any((t) => t.isCompleted) ? _clearCompleted : null,
          )
        ],
      ),
      body: _tasks.isEmpty ? const Center(child: Text('Нет дел. Добавьте первое!')) : ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return ItemTile(
            title: task.title,
            subtitle: '${task.category} • ${task.periodicity}',
            isCompleted: task.isCompleted,
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
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _openAddEdit(),
      ),
    );
  }
}
