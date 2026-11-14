import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';

/// Семейный блокнот: цветные заметки с поиском, категорией и фото.
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

  static const List<String> _categories = ['Рецепт', 'Идея', 'Список', 'Памятка'];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Безопасные геттеры: в базе любое поле может оказаться NULL ---

  String _text(Map<String, dynamic> note, String key) {
    final value = note[key];
    if (value == null) return '';
    return value.toString();
  }

  Color _noteColor(Map<String, dynamic> note) {
    final value = note['color'];
    if (value is int) return Color(value);
    return Colors.yellow.shade100;
  }

  Future<void> _loadNotes() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('notes', orderBy: 'date DESC');
    if (!mounted) return;
    setState(() {
      _allNotes = maps;
      _filteredNotes = _filterByQuery(maps, _searchQuery);
    });
  }

  List<Map<String, dynamic>> _filterByQuery(
    List<Map<String, dynamic>> notes,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return notes;

    return notes.where((note) {
      final title = _text(note, 'title').toLowerCase();
      final content = _text(note, 'content').toLowerCase();
      final category = _text(note, 'category').toLowerCase();
      return title.contains(q) || content.contains(q) || category.contains(q);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredNotes = _filterByQuery(_allNotes, query);
    });
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? note}) async {
    final titleController =
        TextEditingController(text: note == null ? '' : _text(note, 'title'));
    final contentController =
        TextEditingController(text: note == null ? '' : _text(note, 'content'));

    final savedCategory = note == null ? '' : _text(note, 'category');
    String selectedCategory = _categories.contains(savedCategory)
        ? savedCategory
        : _categories.first;

    Color selectedColor =
        note == null ? Colors.yellow.shade100 : _noteColor(note);
    String? photoPath = note == null ? null : note['photo_path'] as String?;

    final colors = <Color>[
      Colors.yellow.shade100,
      Colors.green.shade100,
      Colors.blue.shade100,
      Colors.pink.shade100,
      Colors.orange.shade100,
    ];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categoryItems = <String>[..._categories];
          if (!categoryItems.contains(selectedCategory)) {
            categoryItems.insert(0, selectedCategory);
          }

          return AlertDialog(
            title: Text(note == null ? 'Новая заметка' : 'Редактировать'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (photoPath != null && File(photoPath!).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Image.file(File(photoPath!), height: 120),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setDialogState(() => photoPath = picked.path);
                      }
                    },
                    icon: const Icon(Icons.photo),
                    label: const Text('Прикрепить фото'),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок (о чём заметка?)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                    ),
                    items: categoryItems
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Текст заметки',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Цвет заметки:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colors.map((color) {
                      final isSelected = selectedColor.value == color.value;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    _showMessage('Напишите заголовок!');
                    return;
                  }

                  final content = contentController.text.trim();
                  final data = <String, dynamic>{
                    'title': title,
                    'content': content.isEmpty ? title : content,
                    'category': selectedCategory,
                    'date': DateTime.now().toIso8601String(),
                    'color': selectedColor.value,
                    'photo_path': photoPath,
                  };

                  try {
                    final db = await DatabaseHelper.instance.database;
                    if (note == null) {
                      await db.insert('notes', data);
                    } else {
                      await db.update(
                        'notes',
                        data,
                        where: 'id = ?',
                        whereArgs: [note['id']],
                      );
                    }
                    if (mounted) Navigator.pop(dialogContext);
                    await _loadNotes();
                  } catch (e) {
                    _showMessage('Ошибка: $e');
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: const Text('Удалить эту заметку?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseHelper.instance.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [note['id']]);
    await _loadNotes();
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final photoPath = note['photo_path'];
    final hasPhoto = photoPath is String &&
        photoPath.isNotEmpty &&
        File(photoPath).existsSync();

    return GestureDetector(
      onTap: () => _showAddEditDialog(note: note),
      onLongPress: () => _deleteNote(note),
      child: Card(
        color: _noteColor(note),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto)
              Image.file(
                File(photoPath),
                width: double.infinity,
                height: 80,
                fit: BoxFit.cover,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(note, 'title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _text(note, 'category').isEmpty
                            ? 'Разное'
                            : _text(note, 'category'),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        _text(note, 'content'),
                        style: const TextStyle(fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по заметкам...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filteredNotes.isEmpty
          ? Center(
              child: Text(
                _searchQuery.isEmpty
                    ? 'Заметок пока нет. Нажмите +, чтобы создать!'
                    : 'Ничего не найдено',
                textAlign: TextAlign.center,
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) =>
                  _buildNoteCard(_filteredNotes[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
