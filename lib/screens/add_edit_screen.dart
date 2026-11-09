import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../models/purchase.dart';

class AddEditScreen extends StatefulWidget {
  final String type;
  final dynamic item;
  final List<String> categories;

  const AddEditScreen({super.key, required this.type, this.item, required this.categories});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _titleController = TextEditingController();
  late String _selectedCategory;
  String _periodicity = 'Разово';
  DateTime? _dueDate;
  
  // Переменные для счетчиков
  bool _isMeter = false;
  final _readingController = TextEditingController();
  int _remindDays = 1;
  
  // Категории, где показываем переключатель счетчика
  final List<String> _homeCategories = ['Дом', 'Коммуналка', 'Быт']; 
  
  final List<String> _periodicities = ['Ежедневно', 'Ежемесячно', 'Ежегодно', 'Разово'];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item.title;
      _selectedCategory = widget.item.category;
      _periodicity = widget.item.periodicity;
      
      if (widget.item.dueDate != null) {
        _dueDate = DateTime.parse(widget.item.dueDate);
      }
      
      // Если это счетчик, подгружаем старые данные
      if (widget.item.readingValue != null) {
        _isMeter = true;
        _readingController.text = widget.item.readingValue;
      }
    } else {
      _selectedCategory = widget.categories.contains('Общее') ? 'Общее' : (widget.categories.isNotEmpty ? widget.categories.first : 'Общее');
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    
    // Формируем дату дедлайна
    String? dateToSave;
    if (_periodicity == 'Ежедневно') {
      dateToSave = null; 
    } else if (_periodicity == 'Ежемесячно') {
      final now = DateTime.now();
      // Если дата не выбрана, ставим сегодняшнее число
      int day = _dueDate?.day ?? now.day;
      dateToSave = "${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
    } else {
      dateToSave = _dueDate != null ? _dueDate!.toIso8601String().split('T')[0] : null;
    }

    final data = {
      'title': _titleController.text,
      'category': _selectedCategory,
      'periodicity': _periodicity,
      'isCompleted': widget.item?.isCompleted == true ? 1 : 0,
      'due_date': dateToSave,
      'reading_value': _isMeter ? _readingController.text : null,
    };

    if (widget.item == null) {
      if (widget.type == 'task') {
        final taskId = await db.insert('tasks', Task(
          title: data['title'] as String, 
          category: data['category'] as String, 
          periodicity: data['periodicity'] as String, 
          dueDate: data['due_date'] as String?,
          readingValue: data['reading_value'] as String?
        ).toMap());
        
        // Если ввели показания, сохраняем в историю
        if (_isMeter && _readingController.text.isNotEmpty) {
          await db.insert('meter_readings', {
            'task_id': taskId,
            'reading_value': double.tryParse(_readingController.text.replaceAll(',', '.')) ?? 0.0,
            'date': DateTime.now().toIso8601String(),
          });
        }
      } else {
        await db.insert('purchases', Purchase(title: data['title'] as String, category: data['category'] as String, periodicity: data['periodicity'] as String).toMap());
      }
    } else {
      await db.update(widget.type == 'task' ? 'tasks' : 'purchases', data, where: 'id = ?', whereArgs: [widget.item.id]);
      
      // Если обновили показания, добавляем запись в историю
      if (widget.type == 'task' && _isMeter && _readingController.text.isNotEmpty && _readingController.text != widget.item.readingValue) {
         await db.insert('meter_readings', {
            'task_id': widget.item.id,
            'reading_value': double.tryParse(_readingController.text.replaceAll(',', '.')) ?? 0.0,
            'date': DateTime.now().toIso8601String(),
          });
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? (widget.type == 'task' ? 'Новое дело' : 'Новая покупка') : 'Редактировать')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController, 
                decoration: const InputDecoration(labelText: 'Название'), 
                autofocus: widget.item == null
              ),
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
              const SizedBox(height: 16),

              // Выбор даты (календарь)
              if (widget.type == 'task' && _periodicity != 'Ежедневно' && !_isMeter)
                ListTile(
                  title: Text(_dueDate == null ? 'Установить дату (дедлайн)' : 'Дедлайн: ${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}'),
                  leading: const Icon(Icons.calendar_today),
                  trailing: _dueDate != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _dueDate = null)) : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
              
              // Блок счетчиков (только для категорий Дом/Коммуналка и только для дел)
              if (widget.type == 'task' && _homeCategories.contains(_selectedCategory)) ...[
                const Divider(),
                SwitchListTile(
                  title: const Text('Это показания счетчика?', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Создаст задачу с напоминанием и полем для ввода цифр'),
                  value: _isMeter,
                  activeColor: Colors.teal,
                  onChanged: (v) => setState(() => _isMeter = v),
                ),
                if (_isMeter) ...[
                  TextField(
                    controller: _readingController,
                    decoration: const InputDecoration(labelText: 'Текущие показания (цифры)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _remindDays,
                    decoration: const InputDecoration(labelText: 'Напомнить за (дней) до подачи'),
                    items: [1, 2, 3].map((d) => DropdownMenuItem(value: d, child: Text('$d дн.'))).toList(),
                    onChanged: (v) => setState(() => _remindDays = v!),
                  ),
                ]
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, 
                height: 50, 
                child: ElevatedButton(
                  onPressed: _save, 
                  child: const Text('Сохранить', style: TextStyle(fontSize: 16))
                )
              )
            ],
          ),
        ),
      ),
    );
  }
}
