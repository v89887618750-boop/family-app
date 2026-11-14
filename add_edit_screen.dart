import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/purchase.dart';
import '../models/task.dart';
import '../utils/notification_service.dart';

/// Универсальный экран создания/редактирования дела или покупки.
///
/// [type] — 'task' или 'purchase'.
/// [item] — Task или Purchase (null при создании новой записи).
class AddEditScreen extends StatefulWidget {
  final String type;
  final dynamic item;
  final List<String> categories;

  const AddEditScreen({
    super.key,
    required this.type,
    this.item,
    required this.categories,
  });

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _readingController = TextEditingController();

  late String _selectedCategory;
  String _periodicity = 'Разово';
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _isMeter = false;
  int _remindDays = 1;

  static const List<String> _homeCategories = ['Дом', 'Коммуналка', 'Быт'];
  static const List<String> _periodicities = [
    'Ежедневно',
    'Ежемесячно',
    'Ежегодно',
    'Разово',
  ];

  static const List<Map<String, String>> _purchasePriorities = [
    {'label': 'Купить сегодня', 'value': 'Разово', 'icon': '🛒'},
    {'label': 'На этой неделе', 'value': 'Ежемесячно', 'icon': '📅'},
    {'label': 'Глобальная покупка', 'value': 'Ежегодно', 'icon': '🌟'},
  ];

  bool get _isTask => widget.type == 'task';
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item is Task) {
      _titleController.text = item.title;
      _selectedCategory = item.category;
      _periodicity = item.periodicity;
      _dueDate = _parseIsoDate(item.dueDate);
      _dueTime = _parseTime(item.dueTime);
      if (item.readingValue != null && item.readingValue!.isNotEmpty) {
        _isMeter = true;
        _readingController.text = item.readingValue!;
      }
    } else if (item is Purchase) {
      _titleController.text = item.title;
      _selectedCategory = item.category;
      _periodicity = item.periodicity;
      _noteController.text = item.note ?? '';
    } else {
      _selectedCategory = widget.categories.contains('Общее')
          ? 'Общее'
          : (widget.categories.isNotEmpty
              ? widget.categories.first
              : 'Общее');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _readingController.dispose();
    super.dispose();
  }

  DateTime? _parseIsoDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Категории для выпадающего списка: если сохранённая категория удалена
  /// из настроек, всё равно показываем её, чтобы Dropdown не упал.
  List<String> get _categoryItems {
    final items = <String>[...widget.categories];
    if (!items.contains(_selectedCategory)) {
      items.insert(0, _selectedCategory);
    }
    return items;
  }

  String? _dueDateForStorage() {
    if (_periodicity == 'Ежедневно') return null;

    if (_periodicity == 'Ежемесячно') {
      final now = DateTime.now();
      final day = _dueDate?.day ?? now.day;
      return _formatDate(DateTime(now.year, now.month, day));
    }

    if (_dueDate == null) return null;
    return _formatDate(_dueDate!);
  }

  String? _dueTimeForStorage() {
    final time = _dueTime;
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage(_isTask ? 'Введите название дела' : 'Введите название покупки');
      return;
    }

    final db = await DatabaseHelper.instance.database;

    try {
      if (_isTask) {
        await _saveTask(db, title);
      } else {
        await _savePurchase(db, title);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showMessage('Ошибка сохранения: $e');
    }
  }

  Future<void> _savePurchase(Database db, String title) async {
    final note = _noteController.text.trim();
    // В таблице purchases есть только эти колонки:
    // title, category, periodicity, isCompleted, note.
    // isCompleted передаём явно: в базах, созданных старыми версиями,
    // у колонки может не быть DEFAULT.
    final map = <String, dynamic>{
      'title': title,
      'category': _selectedCategory,
      'periodicity': _periodicity,
      'note': note.isEmpty ? null : note,
    };

    if (_isEditing) {
      await db.update(
        'purchases',
        map,
        where: 'id = ?',
        whereArgs: [widget.item.id],
      );
    } else {
      map['isCompleted'] = 0;
      await db.insert('purchases', map);
    }
  }

  Future<void> _saveTask(Database db, String title) async {
    final wasCompleted = widget.item is Task ? (widget.item as Task).isCompleted : false;
    final dueDate = _dueDateForStorage();
    final dueTime = _dueTimeForStorage();
    final reading = _isMeter ? _readingController.text.trim() : '';

    final map = <String, dynamic>{
      'title': title,
      'category': _selectedCategory,
      'periodicity': _periodicity,
      'isCompleted': wasCompleted ? 1 : 0,
      'due_date': dueDate,
      'due_time': dueTime,
      'reading_value': reading.isEmpty ? null : reading,
    };

    int taskId;
    if (_isEditing) {
      taskId = widget.item.id as int;
      await db.update('tasks', map, where: 'id = ?', whereArgs: [taskId]);
    } else {
      final inserted = await db.insert(
        'tasks',
        Task(
          title: title,
          category: _selectedCategory,
          periodicity: _periodicity,
          dueDate: dueDate,
          dueTime: dueTime,
          readingValue: reading.isEmpty ? null : reading,
        ).toMap(),
      );
      taskId = inserted;
    }

    // Показания счётчика: добавляем новую точку, если значение введено
    // и отличается от прежнего (или это новая задача).
    if (_isMeter && reading.isNotEmpty) {
      final previous = widget.item is Task ? (widget.item as Task).readingValue : null;
      if (!_isEditing || previous != reading) {
        final value = double.tryParse(reading.replaceAll(',', '.')) ?? 0.0;
        await db.insert('meter_readings', {
          'task_id': taskId,
          'reading_value': value,
          'date': DateTime.now().toIso8601String(),
        });
      }
    }

    await _scheduleReminder(taskId, title, dueDate, dueTime);
  }

  Future<void> _scheduleReminder(
    int taskId,
    String title,
    String? dueDate,
    String? dueTime,
  ) async {
    if (dueDate == null || dueTime == null) return;

    try {
      await NotificationService.cancelNotification(taskId);

      final dateParts = dueDate.split('-');
      final timeParts = dueTime.split(':');
      if (dateParts.length != 3 || timeParts.length != 2) return;

      var scheduled = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      // Для счётчиков напоминаем заранее на N дней.
      if (_isMeter && _remindDays > 0) {
        scheduled = scheduled.subtract(Duration(days: _remindDays));
      }

      if (!scheduled.isAfter(DateTime.now())) return;

      await NotificationService.scheduleNotification(
        id: taskId,
        title: 'Напоминание: $title',
        body: _isMeter ? 'Пора подать показания счётчика' : 'Пора выполнить задачу',
        scheduledDate: scheduled,
      );
    } catch (e) {
      debugPrint('Ошибка установки уведомления: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String appBarTitle;
    if (_isEditing) {
      appBarTitle = 'Редактировать';
    } else {
      appBarTitle = _isTask ? 'Новое дело' : 'Новая покупка';
    }

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                ),
                items: _categoryItems
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // --- Покупка: комментарий и приоритет ---
              if (!_isTask) ...[
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий (например: жидкое, 2 шт., без запаха)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Когда планируем купить?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _purchasePriorities.map((priority) {
                    final value = priority['value']!;
                    return ChoiceChip(
                      label: Text('${priority['icon']} ${priority['label']}'),
                      selected: _periodicity == value,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (_) => setState(() => _periodicity = value),
                    );
                  }).toList(),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _periodicity,
                  decoration: const InputDecoration(
                    labelText: 'Периодичность',
                    border: OutlineInputBorder(),
                  ),
                  items: _periodicities
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _periodicity = value);
                    }
                  },
                ),
              ],

              const SizedBox(height: 16),

              if (_isTask && _periodicity != 'Ежедневно')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _dueDate == null
                        ? 'Установить дату'
                        : 'Дата: ${_formatDate(_dueDate!)}',
                  ),
                  leading: const Icon(Icons.calendar_today),
                  trailing: _dueDate == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                ),

              if (_isTask && _periodicity != 'Ежедневно')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _dueTime == null
                        ? 'Установить время'
                        : 'Время: ${_dueTime!.hour.toString().padLeft(2, '0')}:'
                            '${_dueTime!.minute.toString().padLeft(2, '0')}',
                  ),
                  leading: const Icon(Icons.access_time),
                  trailing: _dueTime == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _dueTime = null),
                        ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _dueTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setState(() => _dueTime = picked);
                    }
                  },
                ),

              if (_isTask && _homeCategories.contains(_selectedCategory)) ...[
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Это показания счётчика?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: _isMeter,
                  activeColor: Colors.teal,
                  onChanged: (value) => setState(() => _isMeter = value),
                ),
                if (_isMeter) ...[
                  TextField(
                    controller: _readingController,
                    decoration: const InputDecoration(
                      labelText: 'Текущие показания (цифры)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _remindDays,
                    decoration: const InputDecoration(
                      labelText: 'Напомнить за (дней) до подачи',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3]
                        .map((d) => DropdownMenuItem(value: d, child: Text('$d дн.')))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _remindDays = value);
                      }
                    },
                  ),
                ],
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
