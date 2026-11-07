import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../models/purchase.dart';

class AddEditScreen extends StatefulWidget {
  final String type;
  const AddEditScreen({super.key, required this.type});
  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Общее');
  String _periodicity = 'Разово';
  final List<String> _periodicities = ['Ежедневно', 'Ежемесячно', 'Ежегодно', 'Разово'];

  Future<void> _save() async {
    if (_titleController.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    if (widget.type == 'task') {
      await db.insert('tasks', Task(title: _titleController.text, category: _categoryController.text, periodicity: _periodicity).toMap());
    } else {
      await db.insert('purchases', Purchase(title: _titleController.text, category: _categoryController.text, periodicity: _periodicity).toMap());
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.type == 'task' ? 'Новое дело' : 'Новая покупка')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Название'), autofocus: true),
          TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Категория')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _periodicity,
            decoration: const InputDecoration(labelText: 'Периодичность'),
            items: _periodicities.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _periodicity = v!),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _save, child: const Text('Сохранить')))
        ]),
      ),
    );
  }
}
