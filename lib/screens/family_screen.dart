import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import 'gifts_screen.dart';

/// «Моя семья»: карточки членов семьи, дата рождения и автоматический
/// расчёт возраста (лет / месяцев / дней).
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<Map<String, dynamic>> _members = [];

  static const List<String> _relations = [
    'Я',
    'Муж',
    'Жена',
    'Сын',
    'Дочь',
    'Отец',
    'Мать',
    'Брат',
    'Сестра',
    'Бабушка',
    'Дедушка',
  ];

  static const List<String> _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.rawQuery('''
      SELECT fm.*, b.date AS bday_date
      FROM family_members fm
      LEFT JOIN birthdays b ON fm.birthday_id = b.id
      ORDER BY fm.id ASC
    ''');
    if (!mounted) return;
    setState(() => _members = maps);
  }

  // ---------------------------------------------------------------------------
  // Работа с датами и возрастом
  // ---------------------------------------------------------------------------

  /// Понимает оба формата, которые встречаются в базе: ДД-ММ-ГГГГ и ГГГГ-ММ-ДД.
  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    final parts = value.split(RegExp(r'[-./]'));
    if (parts.length != 3) return null;

    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;

    final int day;
    final int month;
    final int year;

    if (parts[0].length == 4) {
      // ГГГГ-ММ-ДД
      year = first;
      month = second;
      day = third;
    } else {
      // ДД-ММ-ГГГГ
      day = first;
      month = second;
      year = third;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final date = DateTime(year, month, day);
    // Отсекаем «31 февраля» и подобное.
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  }

  static String _plural(int value, String one, String few, String many) {
    final mod100 = value % 100;
    final mod10 = value % 10;
    if (mod100 >= 11 && mod100 <= 14) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
  }

  /// Возвращает «32 года», «8 месяцев», «12 дней» или '' если даты нет.
  String _ageText(String? rawDate) {
    final birthDate = _parseDate(rawDate);
    if (birthDate == null) return '';

    final now = DateTime.now();
    if (birthDate.isAfter(now)) return '';

    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months -= 1;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    // Защита от отрицательных значений из-за неточных дат.
    if (years < 0) return '';

    if (years >= 1) {
      return '$years ${_plural(years, 'год', 'года', 'лет')}';
    }

    if (months >= 1) {
      return '$months ${_plural(months, 'месяц', 'месяца', 'месяцев')}';
    }

    final days = now.difference(birthDate).inDays;
    return '$days ${_plural(days, 'день', 'дня', 'дней')}';
  }

  /// Ближайший день рождения (через сколько дней) — для подписи на карточке.
  String _nextBirthdayText(String? rawDate) {
    final birthDate = _parseDate(rawDate);
    if (birthDate == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var next = DateTime(now.year, birthDate.month, birthDate.day);
    if (next.isBefore(today)) {
      next = DateTime(now.year + 1, birthDate.month, birthDate.day);
    }

    final days = next.difference(today).inDays;
    if (days == 0) return '🎉 Сегодня!';
    if (days == 1) return 'Завтра';
    return 'Через $days ${_plural(days, 'день', 'дня', 'дней')}';
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  /// Формат, в котором дата хранится в таблице birthdays (как в остальном
  /// приложении — ДД-ММ-ГГГГ).
  static String _storageDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Разбор ФИО
  // ---------------------------------------------------------------------------

  Map<String, String> _splitFullName(String? fullName) {
    var rest = (fullName ?? '').trim();
    var maiden = '';

    // «Иванова Анна Петровна (Смирнова)» → maiden = Смирнова
    final maidenMatch = RegExp(r'\(([^)]*)\)\s*$').firstMatch(rest);
    if (maidenMatch != null) {
      maiden = maidenMatch.group(1)?.trim() ?? '';
      rest = rest.substring(0, maidenMatch.start).trim();
    }

    final parts = rest
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final result = <String, String>{
      'surname': '',
      'name': '',
      'patronymic': '',
      'maiden': maiden,
    };

    if (parts.length >= 2) {
      result['surname'] = parts[0];
      result['name'] = parts[1];
      if (parts.length > 2) {
        result['patronymic'] = parts.sublist(2).join(' ');
      }
    } else if (parts.length == 1) {
      result['name'] = parts[0];
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openWishlist({String? forWhom, String? avatarPath}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GiftsScreen(
          filterForWhom: forWhom,
          avatarPath: avatarPath,
        ),
      ),
    );
  }

  void _showProfile(Map<String, dynamic> member) {
    final photoPath = member['photo_path'] as String?;
    final fullName = (member['name'] as String?) ?? '';
    final relation = (member['relation'] as String?) ?? '';
    final bdayDate = member['bday_date'] as String?;
    final age = _ageText(bdayDate);
    final nextBirthday = _nextBirthdayText(bdayDate);
    final birthDate = _parseDate(bdayDate);
    final shortName = _splitFullName(fullName)['name'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (photoPath != null && File(photoPath).existsSync())
                  CircleAvatar(
                    radius: 56,
                    backgroundImage: FileImage(File(photoPath)),
                  )
                else
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      shortName.isEmpty ? '?' : shortName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32, color: Colors.teal),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    relation,
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (birthDate != null) ...[
                  Text(
                    '🎂 ${_formatDate(birthDate)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    age.isEmpty ? '—' : 'Возраст: $age',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextBirthday,
                    style: const TextStyle(fontSize: 13, color: Colors.teal),
                  ),
                ] else
                  const Text(
                    'Дата рождения не указана',
                    style: TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.card_giftcard),
                  label: Text(
                    'Wishlist: ${shortName.isEmpty ? 'общий' : shortName}',
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openWishlist(
                      forWhom: fullName.isEmpty ? null : fullName,
                      avatarPath: photoPath,
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать профиль'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showAddEditDialog(member: member);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? member}) async {
    final nameParts = _splitFullName(member == null ? null : _asString(member['name']));

    final surnameController =
        TextEditingController(text: nameParts['surname'] ?? '');
    final nameController = TextEditingController(text: nameParts['name'] ?? '');
    final patronymicController =
        TextEditingController(text: nameParts['patronymic'] ?? '');
    final maidenNameController =
        TextEditingController(text: nameParts['maiden'] ?? '');

    String relation = member != null
        ? _asString(member['relation'])
        : 'Сын';
    if (!_relations.contains(relation)) {
      relation = 'Сын';
    }

    String? photoPath = member == null ? null : member['photo_path'] as String?;

    final existingBirthDate =
        _parseDate(member == null ? null : _asString(member['bday_date']));

    int? selectedDay = existingBirthDate?.day;
    int? selectedMonth = existingBirthDate?.month;
    int? selectedYear = existingBirthDate?.year;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final relationItems = <String>[..._relations];
          if (!relationItems.contains(relation)) {
            relationItems.insert(0, relation);
          }

          const border = OutlineInputBorder();

          return AlertDialog(
            title: Text(member == null ? 'Новый член семьи' : 'Редактировать'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (photoPath != null && File(photoPath!).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: FileImage(File(photoPath!)),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setDialogState(() => photoPath = picked.path);
                      }
                    },
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Фото'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: surnameController,
                          decoration: const InputDecoration(
                            labelText: 'Фамилия',
                            border: border,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Имя',
                            border: border,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: patronymicController,
                    decoration: const InputDecoration(
                      labelText: 'Отчество',
                      border: border,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: maidenNameController,
                    decoration: const InputDecoration(
                      labelText: 'Девичья фамилия (если есть)',
                      border: border,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: relation,
                    decoration: const InputDecoration(
                      labelText: 'Кем является?',
                      border: border,
                    ),
                    items: relationItems
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => relation = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Дата рождения',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'День',
                            border: border,
                          ),
                          items: List.generate(31, (i) => i + 1)
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text('$d'),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedDay = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Месяц',
                            border: border,
                          ),
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(_months[m - 1]),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedMonth = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Год',
                            border: border,
                          ),
                          items: List.generate(100, (i) => DateTime.now().year - i)
                              .map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text('$y'),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => selectedYear = value),
                        ),
                      ),
                    ],
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
                  final surname = surnameController.text.trim();
                  final name = nameController.text.trim();
                  final patronymic = patronymicController.text.trim();
                  final maiden = maidenNameController.text.trim();

                  if (surname.isEmpty && name.isEmpty) {
                    _showMessage('Введите хотя бы имя и фамилию');
                    return;
                  }

                  var fullName = [surname, name, patronymic]
                      .where((p) => p.isNotEmpty)
                      .join(' ');
                  if (maiden.isNotEmpty) {
                    fullName = '$fullName ($maiden)';
                  }

                  // Если все три поля выбраны — сохраняем дату рождения.
                  String? storageDate;
                  if (selectedDay != null &&
                      selectedMonth != null &&
                      selectedYear != null) {
                    final date = DateTime(
                      selectedYear!,
                      selectedMonth!,
                      selectedDay!,
                    );
                    storageDate = _storageDate(date);
                  }

                  try {
                    final db = await DatabaseHelper.instance.database;
                    int? birthdayId = member == null
                        ? null
                        : member['birthday_id'] as int?;

                    if (storageDate != null) {
                      if (birthdayId == null) {
                        birthdayId = await db.insert('birthdays', {
                          'name': fullName,
                          'date': storageDate,
                          'category': relation,
                          'remind_days': 1,
                          'photo_path': photoPath,
                        });
                      } else {
                        await db.update(
                          'birthdays',
                          {
                            'name': fullName,
                            'date': storageDate,
                            'category': relation,
                            'photo_path': photoPath,
                          },
                          where: 'id = ?',
                          whereArgs: [birthdayId],
                        );
                      }
                    }

                    final memberData = <String, dynamic>{
                      'name': fullName,
                      'relation': relation,
                      'photo_path': photoPath,
                      'birthday_id': birthdayId,
                    };

                    if (member == null) {
                      await db.insert('family_members', memberData);
                    } else {
                      await db.update(
                        'family_members',
                        memberData,
                        where: 'id = ?',
                        whereArgs: [member['id']],
                      );
                    }

                    if (mounted) Navigator.pop(dialogContext);
                    await _loadMembers();
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

  String _asString(dynamic value) => value is String ? value : (value?.toString() ?? '');

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    final name = _asString(member['name']);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Удалить "$name" из семьи?'),
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
    final birthdayId = member['birthday_id'] as int?;

    await db.delete('family_members', where: 'id = ?', whereArgs: [member['id']]);

    // Если на эту дату рождения больше никто не ссылается — убираем и её,
    // чтобы в «Днях рождения» не оставался дубль.
    if (birthdayId != null) {
      final count = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM family_members WHERE birthday_id = ?',
            [birthdayId],
          )) ??
          0;
      if (count == 0) {
        await db.delete('birthdays', where: 'id = ?', whereArgs: [birthdayId]);
      }
    }

    await _loadMembers();
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final photoPath = member['photo_path'] as String?;
    final name = _asString(member['name']);
    final relation = _asString(member['relation']);
    final bdayDate = member['bday_date'] as String?;
    final age = _ageText(bdayDate);
    final birthDate = _parseDate(bdayDate);
    final shortName = _splitFullName(name)['name'] ?? '';
    final hasPhoto = photoPath != null && File(photoPath).existsSync();

    return Slidable(
      key: ValueKey('member-${member['id']}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteMember(member),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Удалить',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showProfile(member),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPhoto)
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: FileImage(File(photoPath)),
                  )
                else
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      shortName.isEmpty ? '?' : shortName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 24, color: Colors.teal),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  relation,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                if (birthDate != null) ...[
                  Text(
                    '🎂 ${_formatDate(birthDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (age.isNotEmpty)
                    Text(
                      age,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ] else
                  const Text(
                    'Нет даты рождения',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя семья'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.card_giftcard, color: Colors.teal),
            label: const Text(
              'Wishlist',
              style: TextStyle(fontSize: 16, color: Colors.teal),
            ),
            onPressed: () => _openWishlist(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _members.isEmpty
          ? const Center(
              child: Text(
                'В семье пока никого нет. Добавьте первого!',
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadMembers,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.7,
                ),
                itemCount: _members.length,
                itemBuilder: (context, index) =>
                    _buildMemberCard(_members[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
