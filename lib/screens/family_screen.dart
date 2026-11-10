import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db/database_helper.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() { super.initState(); _loadMembers(); }

  Future<void> _loadMembers() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('family_members');
    setState(() => _members = maps);
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    String relation = 'Сын/Дочь';
    String? photoPath;
    
    final relations = ['Муж', 'Жена', 'Сын', 'Дочь', 'Отец', 'Мать', 'Брат', 'Сестра', 'Бабушка', 'Дедушка'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Новый член семьи'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoPath != null) 
                  CircleAvatar(radius: 30, backgroundImage: FileImage(File(photoPath!))),
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
                  items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
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
                await db.insert('family_members', {
                  'name': nameController.text.trim(),
                  'relation': relation,
                  'photo_path': photoPath,
                });
                if (mounted) Navigator.pop(context);
                _loadMembers();
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
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
                return Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (member['photo_path'] != null && File(member['photo_path']).existsSync())
                        CircleAvatar(radius: 40, backgroundImage: FileImage(File(member['photo_path']))),
                      const SizedBox(height: 8),
                      Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(member['relation'], style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.person_add),
        onPressed: _showAddMemberDialog,
      ),
    );
  }
}
