import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../models/purchase.dart';

class AddEditScreen extends StatefulWidget {
  final String type;
  final dynamic item; // Сюда передаем задачу или покупку для редактирования
  final List<String> categories;

  const AddEditScreen({super.key, required this.type, this.item, required this.categories});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _titleController = TextEditingController();
  late String _selectedCategory;
  String _periodicity = 'Разово';
  final List<String> _periodicities = ['Ежедневно', 'Ежемесячно', 'Ежегодно', 'Разово'];

  @override
  void initState() {
    super.initState();
    // Если редактируем, заполняем поля старыми данными
    if (widget.item != null) {
      _titleController.text = widget.item.title;
      _selectedCategory = widget.item.category;
      _periodicity = widget.item.periodicity;
    } else {
      _selectedCategory = widget.categories.contains('Общее') ? 'Общее' : (widget.categories.isNotEmpty ? widget.categories.first : 'Общее');
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    
    final data = {
      'title': _titleController.text,
      'category': _selectedCategory,
      'periodicity': _periodicity,
      'isCompleted': widget.item?.isCompleted == true ? 1 : 0,
    };

    if (widget.item == null) {
      // Создаем новое
      if (widget.type == 'task') {
        await db.insert('tasks', Task(title: data['title'], category: data['category'], periodicity: data['periodicity']).toMap());
      } else {
        await db.insert('purchases', Purchase(title: data['title'], category: data['category'], periodicity: data['periodicity']).toMap());
      }
    } else {
      // Обновляем старое
      await db.update(widget.type == 'task' ? 'tasks' : 'purchases', data, where: 'id = ?', whereArgs: [widget.item.id]);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? (widget.type == 'task' ? 'Новое дело' : 'Новая покупка') : 'Редактировать')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Название'), autofocus: widget.item == null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: widget.categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
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
