import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../db/database_helper.dart';
import '../models/gift.dart';

class GiftsScreen extends StatefulWidget {
  final String? filterForWhom; 
  final String? avatarPath;

  const GiftsScreen({super.key, this.filterForWhom, this.avatarPath});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  List<Gift> _gifts = [];
  List<String> _familyNames = []; // Список имен для выбора

  @override
  void initState() { 
    super.initState(); 
    _loadGifts(); 
    _loadFamilyNames();
  }

  Future<void> _loadFamilyNames() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('family_members');
    final names = maps.map((e) => e['name'] as String).toList();
    // Добавляем "Общее" на случай, если хочется подарить что-то семье
    if (!names.contains('Общее')) names.add('Общее');
    setState(() => _familyNames = names);
  }

  Future<void> _loadGifts() async {
    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> maps;
    if (widget.filterForWhom != null) {
      maps = await db.query('gifts', where: 'forWhom = ?', whereArgs: [widget.filterForWhom]);
    } else {
      maps = await db.query('gifts');
    }
    setState(() => _gifts = maps.map((e) => Gift.fromMap(e)).toList());
  }

  void _showAddEditDialog({Gift? item}) {
    final titleController = TextEditingController(text: item?.title ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');
    
    // Если мы зашли из профиля ДР, подставляем имя. Иначе - первое из списка или 'Общее'
    String targetForWhom = item?.forWhom ?? widget.filterForWhom ?? (_familyNames.isNotEmpty ? _familyNames.first : 'Общее');
    String? photoPath = item?.photoPath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Добавить желание' : 'Редактировать'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoPath != null) 
                  Image.file(File(photoPath!), height: 100),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setDialogState(() => photoPath = picked.path);
                  },
                  icon: const Icon(Icons.photo), label: const Text('Выбрать фото'),
                ),
                TextField(
                  controller: titleController, 
                  decoration: const InputDecoration(labelText: 'Что подарить? (или ссылка)'),
                ),
                TextField(
                  controller: noteController, 
                  decoration: const InputDecoration(labelText: 'Описание (размер, цвет, пожелания)'),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 16),
                // ВЫБОР ЧЛЕНА СЕМЬИ (только если мы не в профиле конкретного человека)
                if (widget.filterForWhom == null) 
                  DropdownButtonFormField<String>(
                    value: targetForWhom,
                    decoration: const InputDecoration(labelText: 'Для кого желание?'),
                    items: _familyNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                    onChanged: (v) => setDialogState(() => targetForWhom = v!),
                  )
                else
                   Padding(
                     padding: const EdgeInsets.only(top: 16),
                     child: Text('Список: ${widget.filterForWhom}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                   )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Напишите, что подарить!')),
                  );
                  return;
                }
                
                final db = await DatabaseHelper.instance.database;
                final gift = Gift(
                  title: titleController.text.trim(), 
                  forWhom: targetForWhom, 
                  category: 'Подарок', 
                  isBought: item?.isBought ?? false,
                  note: noteController.text.trim(),
                  photoPath: photoPath
                );
                
                try {
                  if (item == null) {
                    await db.insert('gifts', gift.toMap());
                  } else {
                    await db.update('gifts', gift.toMap(), where: 'id = ?', whereArgs: [item.id]);
                  }
                  if (mounted) Navigator.pop(context);
                  _loadGifts();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка сохранения: $e')),
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

  Future<void> _confirmDelete(Gift gift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Вы уверены, что хотите удалить "${gift.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('gifts', where: 'id = ?', whereArgs: [gift.id]);
      _loadGifts();
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Gift>> groupedGifts = {};
    if (widget.filterForWhom == null) {
      for (var gift in _gifts) {
        groupedGifts.putIfAbsent(gift.forWhom, () => []).add(gift);
      }
    } else {
      groupedGifts[widget.filterForWhom!] = _gifts;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.filterForWhom != null ? 'Wishlist: ${widget.filterForWhom}' : 'Все Wishlist-ы')),
      body: _gifts.isEmpty ? const Center(child: Text('Список желаний пуст')) : ListView(
        children: groupedGifts.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    if (widget.filterForWhom != null && widget.avatarPath != null && File(widget.avatarPath!).existsSync())
                      CircleAvatar(radius: 20, backgroundImage: FileImage(File(widget.avatarPath!)))
                    else
                      CircleAvatar(radius: 20, backgroundColor: Colors.teal.shade100, child: Text(entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?')),
                    const SizedBox(width: 12),
                    Text(entry.key == 'Общее' ? 'Общие желания' : 'Wishlist: ${entry.key}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
              ),
              ...entry.value.map((gift) => Slidable(
                key: Key(gift.id.toString()),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) => _confirmDelete(gift), 
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Удалить',
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    onTap: () => _showAddEditDialog(item: gift),
                    leading: gift.photoPath != null && File(gift.photoPath!).existsSync()
                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(gift.photoPath!), width: 50, height: 50, fit: BoxFit.cover))
                        : Checkbox(
                            value: gift.isBought,
                            onChanged: (_) async {
                              final db = await DatabaseHelper.instance.database;
                              gift.isBought = !gift.isBought;
                              await db.update('gifts', gift.toMap(), where: 'id = ?', whereArgs: [gift.id]);
                              _loadGifts();
                            },
                          ),
                    title: Text(gift.title, style: TextStyle(decoration: gift.isBought ? TextDecoration.lineThrough : null, color: gift.isBought ? Colors.grey : null)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (gift.note != null && gift.note!.isNotEmpty) Text(gift.note!, style: const TextStyle(fontSize: 12)),
                        if (gift.title.startsWith('http') || (gift.note?.startsWith('http') ?? false))
                          InkWell(
                            onTap: () async {
                              final url = Uri.parse(gift.title.startsWith('http') ? gift.title : gift.note!);
                              if (await canLaunchUrl(url)) launchUrl(url);
                            },
                            child: const Text('Открыть ссылку', style: TextStyle(color: Colors.blue, fontSize: 12)),
                          ),
                      ],
                    ),
                    trailing: Checkbox( 
                      value: gift.isBought,
                      onChanged: (_) async {
                        final db = await DatabaseHelper.instance.database;
                        gift.isBought = !gift.isBought;
                        await db.update('gifts', gift.toMap(), where: 'id = ?', whereArgs: [gift.id]);
                        _loadGifts();
                      },
                    ),
                  ),
                ),
              )),
            ],
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(child: const Icon(Icons.add), onPressed: () => _showAddEditDialog()),
    );
  }
}
