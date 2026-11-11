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

  @override
  void initState() { super.initState(); _loadMembers(); }

  Future<void> _loadMembers() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('family_members');
    setState(() => _members = maps);
  }

  void _showAddEditDialog({Map<String, dynamic>? member}) {
    final nameController = TextEditingController(text: member != null ? member['name'] : '');
    String relation = member != null ? member['relation'] : 'Сын';
    String? photoPath = member != null ? member['photo_path'] : null;

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
                  // ИСПРАВЛЕНО ЗДЕСЬ: добавили восклицательный знак
                  CircleAvatar(radius: 40, backgroundImage: FileImage(File(photoPath!))),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setDialogState(() => photoPath = picked.path);
                  },
                  icon: const Icon(Icons.photo_camera), label: const Text('Фото'),
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: relation,
                  decoration: const InputDecoration(labelText: 'Кем является?'),
                  items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => relation = v!),
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
                
                if (member == null) {
                  await db.insert('family_members', {
                    'name': nameController.text.trim(),
                    'relation': relation,
                    'photo_path': photoPath,
                  });
                } else {
                  await db.update('family_members', {
                    'name': nameController.text.trim(),
                    'relation': relation,
                    'photo_path': photoPath,
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
                          // ИСПРАВЛЕНО ЗДЕСЬ: добавили восклицательный знак
                          if (member['photo_path'] != null && File(member['photo_path']).existsSync())
                            CircleAvatar(radius: 40, backgroundImage: FileImage(File(member['photo_path']))),
                          const SizedBox(height: 8),
                          Text(member['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(member['relation'], style: const TextStyle(color: Colors.grey)),
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
