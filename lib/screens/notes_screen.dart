import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() { super.initState(); _loadNotes(); }

  Future<void> _loadNotes() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('notes', orderBy: 'date DESC');
    setState(() => _notes = maps);
  }

  void _showAddEditDialog({Map<String, dynamic>? note}) {
    final titleController = TextEditingController(text: note != null ? note['title'] : '');
    final contentController = TextEditingController(text: note != null ? note['content'] : '');
    Color selectedColor = note != null ? Color(note['color']) : Colors.yellow.shade100;

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
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Заголовок (например: Wi-Fi)')),
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
                if (titleController.text.trim().isEmpty) return;
                final db = await DatabaseHelper.instance.database;
                
                final data = {
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'date': DateTime.now().toIso8601String(),
                  'color': selectedColor.value,
                };

                if (note == null) {
                  await db.insert('notes', data);
                } else {
                  await db.update('notes', data, where: 'id = ?', whereArgs: [note['id']]);
                }
                if (mounted) Navigator.pop(context);
                _loadNotes();
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
      appBar: AppBar(title: const Text('Семейный блокнот')),
      body: _notes.isEmpty 
          ? const Center(child: Text('Заметок пока нет. Нажмите +, чтобы создать!'))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                final color = Color(note['color']);
                return GestureDetector(
                  onTap: () => _showAddEditDialog(note: note),
                  onLongPress: () => _deleteNote(note['id']),
                  child: Card(
                    color: color,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(note['content'], style: const TextStyle(fontSize: 13), maxLines: 5, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
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
