import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../db/database_helper.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _allNotes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = ['Рецепт', 'Идея', 'Список', 'Памятка'];

  @override
  void initState() { super.initState(); _loadNotes(); }

  Future<void> _loadNotes() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('notes', orderBy: 'date DESC');
    setState(() {
      _allNotes = maps;
      _filterNotes(_searchQuery);
    });
  }

  void _filterNotes(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredNotes = _allNotes;
      } else {
        _filteredNotes = _allNotes.where((note) {
          final title = note['title'].toString().toLowerCase();
          final content = note['content'].toString().toLowerCase();
          final category = (note['category'] ?? '').toString().toLowerCase();
          return title.contains(query.toLowerCase()) || 
                 content.contains(query.toLowerCase()) || 
                 category.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showAddEditDialog({Map<String, dynamic>? note}) {
    final titleController = TextEditingController(text: note != null ? note['title'] : '');
    final contentController = TextEditingController(text: note != null ? note['content'] : '');
    String selectedCategory = note != null && note['category'] != null ? note['category'] : _categories[0];
    Color selectedColor = note != null ? Color(note['color']) : Colors.yellow.shade100;
    String? photoPath = note != null ? note['photo_path'] : null;

    final colors = [
      Colors.yellow.shade100,
      Colors.green.shade100,
      Colors.blue.shade100,
      Colors.pink.shade100,
      Colors.orange.shade100,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(note == null ? 'Новая заметка' : 'Редактировать'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoPath != null)
                  Image.file(File(photoPath), height: 100),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setDialogState(() => photoPath = picked.path);
                  },
                  icon: const Icon(Icons.photo), label: const Text('Прикрепить фото'),
                ),
                
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Заголовок (о чём заметка?)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Категория'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: contentController, decoration: const InputDecoration(labelText: 'Текст заметки'), maxLines: 4),
                const SizedBox(height: 16),
                const Text('Цвет заметки:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((c) => GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: c, 
                        shape: BoxShape.circle,
                        border: Border.all(color: selectedColor == c ? Colors.black : Colors.transparent, width: 2)
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Напишите заголовок!')));
                  return;
                }
                final db = await DatabaseHelper.instance.database;
                
                final data = {
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'category': selectedCategory,
                  'date': DateTime.now().toIso8601String(),
                  'color': selectedColor.value,
                  'photo_path': photoPath,
                };

                try {
                  if (note == null) {
                    await db.insert('notes', data);
                  } else {
                    await db.update('notes', data, where: 'id = ?', whereArgs: [note['id']]);
                  }
                  if (mounted) Navigator.pop(context);
                  _loadNotes();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: const Text('Удалить эту заметку?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('notes', where: 'id = ?', whereArgs: [id]);
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Семейный блокнот'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterNotes,
              decoration: InputDecoration(
                hintText: 'Поиск по заметкам...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _filteredNotes.isEmpty 
          ? Center(child: Text(_searchQuery.isEmpty ? 'Заметок пока нет. Нажмите +, чтобы создать!' : 'Ничего не найдено'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
                final note = _filteredNotes[index];
                final color = Color(note['color']);
                return GestureDetector(
                  onTap: () => _showAddEditDialog(note: note),
                  onLongPress: () => _deleteNote(note['id']),
                  child: Card(
                    color: color,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note['photo_path'] != null && File(note['photo_path']).existsSync())
                          Image.file(
                            File(note['photo_path']),
                            width: double.infinity,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                                child: Text(note['category'] ?? 'Разное', style: const TextStyle(fontSize: 10)),
                              ),
                              const SizedBox(height: 8),
                              Text(note['content'], style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddEditDialog(),
      ),
    );
  }
}
