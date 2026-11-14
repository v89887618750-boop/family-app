import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/database_helper.dart';
import '../models/gift.dart';

/// Семейный Wishlist (список желаний).
///
/// [filterForWhom] — если задан, показываем желания только этого человека
/// (переход из профиля члена семьи / из списка ДР).
class GiftsScreen extends StatefulWidget {
  final String? filterForWhom;
  final String? avatarPath;

  const GiftsScreen({super.key, this.filterForWhom, this.avatarPath});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  List<Gift> _gifts = [];
  List<String> _familyNames = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadFamilyNames();
    await _loadGifts();
  }

  Future<void> _loadFamilyNames() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('family_members', orderBy: 'name ASC');
    final names = <String>[];
    for (final map in maps) {
      final name = map['name'];
      if (name is String && name.trim().isNotEmpty) {
        names.add(name.trim());
      }
    }
    if (!names.contains('Общее')) {
      names.add('Общее');
    }

    if (!mounted) return;
    setState(() => _familyNames = names);
  }

  Future<void> _loadGifts() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps;

    if (widget.filterForWhom != null) {
      maps = await db.query(
        'gifts',
        where: 'forWhom = ?',
        whereArgs: [widget.filterForWhom],
      );
    } else {
      maps = await db.query('gifts');
    }

    if (!mounted) return;
    setState(() => _gifts = maps.map((e) => Gift.fromMap(e)).toList());
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showAddEditDialog({Gift? item}) async {
    // Перед открытием диалога убеждаемся, что имена семьи загружены.
    if (_familyNames.isEmpty) {
      await _loadFamilyNames();
    }

    final titleController = TextEditingController(text: item?.title ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');

    String targetForWhom = item?.forWhom ??
        widget.filterForWhom ??
        (_familyNames.isNotEmpty ? _familyNames.first : 'Общее');
    String? photoPath = item?.photoPath;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final items = <String>[..._familyNames];
          if (!items.contains(targetForWhom)) {
            items.insert(0, targetForWhom);
          }

          return AlertDialog(
            title: Text(item == null ? 'Добавить желание' : 'Редактировать'),
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
                    label: const Text('Выбрать фото'),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Что подарить? (или ссылка)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Описание (размер, цвет, пожелания)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  if (widget.filterForWhom == null)
                    DropdownButtonFormField<String>(
                      value: targetForWhom,
                      decoration: const InputDecoration(
                        labelText: 'Для кого желание?',
                        border: OutlineInputBorder(),
                      ),
                      items: items
                          .map((name) =>
                              DropdownMenuItem(value: name, child: Text(name)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => targetForWhom = value);
                        }
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Список: ${widget.filterForWhom}',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                    _showMessage('Напишите, что подарить!');
                    return;
                  }

                  final note = noteController.text.trim();

                  // ВАЖНО: карта без id — иначе UPDATE писал бы NULL в PRIMARY KEY
                  // и сохранение падало с ошибкой SQLite.
                  final gift = Gift(
                    title: title,
                    forWhom: targetForWhom,
                    category: item?.category ?? 'Подарок',
                    isBought: item?.isBought ?? false,
                    note: note.isEmpty ? null : note,
                    photoPath: photoPath,
                    // Сохраняем бронь, выставленную другим членом семьи.
                    reservedBy: item?.reservedBy,
                  );

                  try {
                    final db = await DatabaseHelper.instance.database;
                    if (item == null) {
                      await db.insert('gifts', gift.toMap());
                    } else {
                      await db.update(
                        'gifts',
                        gift.toMap(),
                        where: 'id = ?',
                        whereArgs: [item.id],
                      );
                    }
                    if (mounted) Navigator.pop(dialogContext);
                    await _loadGifts();
                  } catch (e) {
                    _showMessage('Ошибка сохранения: $e');
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

  Future<void> _toggleBought(Gift gift) async {
    final db = await DatabaseHelper.instance.database;
    gift.isBought = !gift.isBought;
    await db.update(
      'gifts',
      {'isBought': gift.isBought ? 1 : 0},
      where: 'id = ?',
      whereArgs: [gift.id],
    );
    await _loadGifts();
  }

  Future<void> _confirmDelete(Gift gift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Вы уверены, что хотите удалить "${gift.title}"?'),
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
    await db.delete('gifts', where: 'id = ?', whereArgs: [gift.id]);
    await _loadGifts();
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showMessage('Не удалось открыть ссылку');
    }
  }

  String? _giftLink(Gift gift) {
    if (gift.title.trim().toLowerCase().startsWith('http')) {
      return gift.title.trim();
    }
    final note = gift.note?.trim();
    if (note != null && note.toLowerCase().startsWith('http')) {
      return note;
    }
    return null;
  }

  Widget _buildGiftTile(Gift gift) {
    final link = _giftLink(gift);
    final avatarText = gift.title.trim().isEmpty
        ? '?'
        : gift.title.trim()[0].toUpperCase();

    return Slidable(
      key: ValueKey('gift-${gift.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _confirmDelete(gift),
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
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(gift.photoPath!),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              : CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(avatarText),
                ),
          title: Text(
            gift.title,
            style: TextStyle(
              decoration: gift.isBought ? TextDecoration.lineThrough : null,
              color: gift.isBought ? Colors.grey : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gift.note != null && gift.note!.trim().isNotEmpty)
                Text(gift.note!, style: const TextStyle(fontSize: 12)),
              if (gift.reservedBy != null && gift.reservedBy!.trim().isNotEmpty)
                Text(
                  'Зарезервировано: ${gift.reservedBy}',
                  style: const TextStyle(fontSize: 11, color: Colors.orange),
                ),
              if (link != null)
                InkWell(
                  onTap: () => _openLink(link),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Открыть ссылку',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          trailing: Checkbox(
            value: gift.isBought,
            onChanged: (_) => _toggleBought(gift),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String groupName) {
    final isCommon = groupName == 'Общее';
    final title = isCommon ? 'Общие желания' : 'Wishlist: $groupName';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (widget.filterForWhom != null &&
              widget.avatarPath != null &&
              File(widget.avatarPath!).existsSync())
            CircleAvatar(
              radius: 20,
              backgroundImage: FileImage(File(widget.avatarPath!)),
            )
          else if (isCommon)
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFB2DFDB),
              child: Icon(Icons.favorite, color: Colors.teal, size: 20),
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.teal.shade100,
              child: Text(
                groupName.isEmpty ? '?' : groupName[0].toUpperCase(),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedGifts = <String, List<Gift>>{};
    if (widget.filterForWhom == null) {
      for (final gift in _gifts) {
        groupedGifts.putIfAbsent(gift.forWhom, () => []).add(gift);
      }
    } else {
      groupedGifts[widget.filterForWhom!] = _gifts;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.card_giftcard, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.filterForWhom != null
                    ? 'Wishlist: ${widget.filterForWhom}'
                    : 'Семейный Wishlist',
              ),
            ),
          ],
        ),
      ),
      body: _gifts.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Список желаний пуст.\nНажмите +, чтобы добавить!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  for (final entry in groupedGifts.entries) ...[
                    _buildHeader(entry.key),
                    for (final gift in entry.value) _buildGiftTile(gift),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
