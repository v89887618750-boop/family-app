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
  @override
  void initState() { super.initState(); _loadTasks(); }

  Future<void> _loadTasks() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    setState(() => _tasks = maps.map((e) => Task.fromMap(e)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Список дел')),
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
              _loadTasks();
            },
            onDelete: () async {
              final db = await DatabaseHelper.instance.database;
              await db.delete('tasks', where: 'id = ?', whereArgs: [task.id]);
              _loadTasks();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditScreen(type: 'task')));
          if (result == true) _loadTasks();
        },
      ),
    );
  }
}
