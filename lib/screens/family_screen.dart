import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../db/database_helper.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<Map<String, dynamic>> _members = [];
  final List<String> _relations = ['Я', 'Муж', 'Жена', 'Сын', 'Дочь', 'Отец', 'Мать', 'Брат', 'Сестра', 'Бабушка', 'Дедушка'];
  final List<String> _months = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  @override
  void initState() { super.initState(); _loadMembers(); }

  Future<void> _loadMembers() async {
    final db = await DatabaseHelper.instance.database;
    // Делаем JOIN, чтобы сразу вытащить дату рождения
    final maps = await db.rawQuery('''
      SELECT fm.*, b.date as bday_date 
      FROM family_members fm
      LEFT JOIN birthdays b ON fm.birthday_id = b.id
    ''');
    setState(() => _members = maps);
  }

  void _showAddEditDialog({Map<String, dynamic>? member}) {
    final nameController = TextEditingController(text: member != null ? member['name'] : '');
    String relation = member != null ? member['relation'] : 'Сын';
    String? photoPath = member != null ? member['photo_path'] : null;

    int? selectedDay;
    int? selectedMonth;
    int? selectedYear;

    // Если редактируем, парсим существующую дату в списки
    if (member != null && member['bday_date'] != null) {
      try {
        final parts = member['bday_date'].toString().split('-');
        if (parts.length == 3) {
          selectedDay = int.parse(parts[0]);
          selectedMonth = int.parse(parts[1]);
          selectedYear = int.parse(parts[2]);
        }
      } catch (e) {}
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(member == null ? 'Новый член семьи' : 'Редактировать'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoPath != null) 
                  CircleAvatar(radius: 40, backgroundImage: FileImage(File(photoPath!))),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setDialogState(() => photoPath = picked.path);
                  },
                  icon: const Icon(Icons.photo_camera), label: const Text('Фото'),
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя (ФИО)')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: relation,
                  decoration: const InputDecoration(labelText: 'Кем является?'),
                  items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => relation = v!),
                ),
                
                const SizedBox(height: 16),
                const Text('Дата рождения', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'День', border: OutlineInputBorder()),
                        value: selectedDay,
                        items: List.generate(31, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                        onChanged: (v) => setDialogState(() => selectedDay = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Месяц', border: OutlineInputBorder()),
                        value: selectedMonth,
                        items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_months[m - 1]))).toList(),
                        onChanged: (v) => setDialogState(() => selectedMonth = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Год', border: OutlineInputBorder()),
                        value: selectedYear,
                        items: List.generate(100, (i) => DateTime.now().year - i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (v) => setDialogState(() => selectedYear = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final db = await DatabaseHelper.instance.database;
                
                int? bdayId = member != null ? member['birthday_id'] : null;
                
                // Если дата выбрана, обновляем или создаем ДР
                if (selectedDay != null && selectedMonth != null && selectedYear != null) {
                  String formattedDate = '${selectedDay.toString().padLeft(2, '0')}-${selectedMonth.toString().padLeft(2, '0')}-$selectedYear';
                  
                  if (bdayId == null) {
                    bdayId = await db.insert('birthdays', {
                      'name': nameController.text.trim(),
                      'date': formattedDate,
                      'category': relation,
                      'remind_days': 1,
                      'photo_path': photoPath,
                    });
                  } else {
                    await db.update('birthdays', {
                      'name': nameController.text.trim(),
                      'date': formattedDate,
                      'category': relation,
                      'photo_path': photoPath,
                    }, where: 'id = ?', whereArgs: [bdayId]);
                  }
                }

                if (member == null) {
                  await db.insert('family_members', {
                    'name': nameController.text.trim(),
                    'relation': relation,
                    'photo_path': photoPath,
                    'birthday_id': bdayId,
                  });
                } else {
                  await db.update('family_members', {
                    'name': nameController.text.trim(),
                    'relation': relation,
                    'photo_path': photoPath,
                    'birthday_id': bdayId,
                  }, where: 'id = ?', whereArgs: [member['id']]);
                }
                if (mounted) Navigator.pop(context);
                _loadMembers();
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Удалить "${member['name']}" из семьи?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('family_members', where: 'id = ?', whereArgs: [member['id']]);
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Моя семья')),
      body: _members.isEmpty 
          ? const Center(child: Text('В семье пока никого нет. Добавьте первого!'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                return Slidable(
                  key: Key(member['id'].toString()),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.3,
                    children: [
                      SlidableAction(
                        onPressed: (context) => _deleteMember(member),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                        label: 'Удалить',
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _showAddEditDialog(member: member), 
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (member['photo_path'] != null && File(member['photo_path']).existsSync())
                            CircleAvatar(radius: 40, backgroundImage: FileImage(File(member['photo_path']))),
                          const SizedBox(height: 8),
                          Text(member['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(member['relation'], style: const TextStyle(color: Colors.grey)),
                          // ВЫВОДИМ ДАТУ!
                          if (member['bday_date'] != null)
                            Text(member['bday_date'], style: const TextStyle(fontSize: 12, color: Colors.teal)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: () => _showAddEditDialog(),
      ),
    );
  }
}
