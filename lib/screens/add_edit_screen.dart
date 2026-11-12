import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../models/purchase.dart';
import '../utils/notification_service.dart';

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
  final _noteController = TextEditingController();
  late String _selectedCategory;
  String _periodicity = 'Разово';
  DateTime? _dueDate;
  TimeOfDay? _dueTime; 
  
  bool _isMeter = false;
  final _readingController = TextEditingController();
  int _remindDays = 1;
  final List<String> _homeCategories = ['Дом', 'Коммуналка', 'Быт']; 
  final List<String> _periodicities = ['Ежедневно', 'Ежемесячно', 'Ежегодно', 'Разово'];

  final List<Map<String, String>> _purchasePriorities = [
    {'label': 'Купить сегодня', 'value': 'Разово', 'icon': '🛒'},
    {'label': 'На этой неделе', 'value': 'Ежемесячно', 'icon': '📅'},
    {'label': 'Глобальная покупка', 'value': 'Ежегодно', 'icon': '🌟'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item.title;
      _selectedCategory = widget.item.category;
      _periodicity = widget.item.periodicity;
      
      if (widget.type == 'purchase' && widget.item.note != null) {
        _noteController.text = widget.item.note;
      }
      
      if (widget.item.dueDate != null) {
        _dueDate = DateTime.tryParse(widget.item.dueDate);
      }
      
      if (widget.item.dueTime != null && widget.item.dueTime!.contains(':')) {
        final parts = widget.item.dueTime!.split(':');
        _dueTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      
      if (widget.type == 'task' && widget.item.readingValue != null) {
        _isMeter = true;
        _readingController.text = widget.item.readingValue;
      }
    } else {
      _selectedCategory = widget.categories.contains('Общее') ? 'Общее' : (widget.categories.isNotEmpty ? widget.categories.first : 'Общее');
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    
    String? dateToSave;
    if (_periodicity == 'Ежедневно') {
      dateToSave = null; 
    } else if (_periodicity == 'Ежемесячно') {
      final now = DateTime.now();
      int day = _dueDate?.day ?? now.day;
      dateToSave = "${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
    } else {
      dateToSave = _dueDate != null ? _dueDate!.toIso8601String().split('T')[0] : null;
    }

    String? timeToSave;
    if (_dueTime != null) {
      timeToSave = '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}';
    }

    final data = {
      'title': _titleController.text.trim(),
      'category': _selectedCategory,
      'periodicity': _periodicity,
      'isCompleted': widget.item?.isCompleted == true ? 1 : 0,
      'due_date': dateToSave,
      'due_time': timeToSave, 
      'reading_value': _isMeter ? _readingController.text : null,
      'note': widget.type == 'purchase' ? _noteController.text.trim() : null,
    };

    int? taskId;
    if (widget.item == null) {
      if (widget.type == 'task') {
        taskId = await db.insert('tasks', Task(
          title: data['title'] as String, category: data['category'] as String, 
          periodicity: data['periodicity'] as String, dueDate: data['due_date'] as String?,
          dueTime: data['due_time'] as String?,
          readingValue: data['reading_value'] as String?,
        ).toMap());
        
        if (_isMeter && _readingController.text.isNotEmpty) {
          await db.insert('meter_readings', {
            'task_id': taskId,
            'reading_value': double.tryParse(_readingController.text.replaceAll(',', '.')) ?? 0.0,
            'date': DateTime.now().toIso8601String(),
          });
        }
      } else {
        await db.insert('purchases', Purchase(
          title: data['title'] as String, 
          category: data['category'] as String, 
          periodicity: data['periodicity'] as String,
          note: data['note'] as String?,
        ).toMap());
      }
    } else {
      taskId = widget.item.id;
      await db.update(widget.type == 'task' ? 'tasks' : 'purchases', data, where: 'id = ?', whereArgs: [widget.item.id]);
    }

    // --- ЛОГИКА УВЕДОМЛЕНИЙ ---
    if (widget.type == 'task' && taskId != null && timeToSave != null && dateToSave != null) {
      try {
        await NotificationService.cancelNotification(taskId);
        
        final partsDate = dateToSave.split('-');
        final partsTime = timeToSave.split(':');
        final scheduledDateTime = DateTime(
          int.parse(partsDate[0]), 
          int.parse(partsDate[1]), 
          int.parse(partsDate[2]), 
          int.parse(partsTime[0]), 
          int.parse(partsTime[1])
        );

        if (scheduledDateTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: taskId,
            title: 'Напоминание: ${_titleController.text.trim()}',
            body: 'Пора выполнить задачу!',
            scheduledDate: scheduledDateTime,
          );
        }
      } catch (e) {
        debugPrint('Ошибка установки уведомления: $e');
      }
    }
    // --------------------------

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
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Название'), autofocus: widget.item == null),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Категория'),
                items: widget.categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 16),

              if (widget.type == 'purchase') ...[
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий (например: жидкое, 2 шт., без запаха)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
              ],

              if (widget.type == 'purchase') ...[
                const Text('Когда планируем купить?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _purchasePriorities.map((p) {
                    final isSelected = _periodicity == p['value'];
                    return ChoiceChip(
                      label: Text('${p['icon']} ${p['label']}'),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _periodicity = p['value']!),
                      selectedColor: Colors.teal.shade100,
                    );
                  }).toList(),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _periodicity,
                  decoration: const InputDecoration(labelText: 'Периодичность'),
                  items: _periodicities.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _periodicity = v!),
                ),
              ],

              const SizedBox(height: 16),

              if (widget.type == 'task' && _periodicity != 'Ежедневно')
                ListTile(
                  title: Text(_dueDate == null ? 'Установить дату' : 'Дата: ${_dueDate!.day}.${_dueDate!.month}.${_dueDate!.year}'),
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

              if (widget.type == 'task' && _periodicity == 'Разово')
                ListTile(
                  title: Text(_dueTime == null ? 'Установить время' : 'Время: ${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'),
                  leading: const Icon(Icons.access_time),
                  trailing: _dueTime != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _dueTime = null)) : null,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _dueTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) setState(() => _dueTime = picked);
                  },
                ),
              
              if (widget.type == 'task' && _homeCategories.contains(_selectedCategory)) ...[
                const Divider(),
                SwitchListTile(
                  title: const Text('Это показания счетчика?', style: TextStyle(fontWeight: FontWeight.bold)),
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
                width: double.infinity, height: 50, 
                child: ElevatedButton(onPressed: _save, child: const Text('Сохранить', style: TextStyle(fontSize: 16)))
              )
            ],
          ),
        ),
      ),
    );
  }
}
