import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../utils/person_utils.dart';
import 'gifts_screen.dart';

/// Фамильное древо: узлы-родственники раскладываются по поколениям,
/// связи рисуются через CustomPaint, зум и сдвиг — InteractiveViewer.
///
/// Связи берутся из таблицы `relations`:
///   * `father` / `mother` — `a_id` родитель `b_id`;
///   * `spouse` — `a_id` и `b_id` супруги.
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

/// Узел дерева.
class _TreePerson {
  _TreePerson({
    required this.id,
    required this.fullName,
    required this.relation,
    required this.photoPath,
    required this.birthDate,
  });

  final int id;
  final String fullName;
  final String relation;
  final String? photoPath;
  final String? birthDate;

  int generation = 0;
}

/// Связь между узлами.
class _TreeLink {
  _TreeLink({required this.fromId, required this.toId, required this.type});

  final int fromId;
  final int toId;
  final String type;

  bool get isSpouse => type == 'spouse';
}

/// Готовая раскладка дерева.
class _TreeLayout {
  _TreeLayout({
    required this.persons,
    required this.links,
    required this.positions,
    required this.width,
    required this.height,
  });

  final List<_TreePerson> persons;
  final List<_TreeLink> links;
  final Map<int, Offset> positions;
  final double width;
  final double height;
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  static const double _nodeWidth = 132;
  static const double _nodeHeight = 128;
  static const double _gapX = 24;
  static const double _rowHeight = 210;
  static const double _padding = 48;

  bool _loading = true;
  _TreeLayout? _layout;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    if (!_loading) {
      setState(() => _loading = true);
    }

    final db = await DatabaseHelper.instance.database;
    final memberRows = await db.rawQuery('''
      SELECT fm.*, b.date AS bday_date
      FROM family_members fm
      LEFT JOIN birthdays b ON fm.birthday_id = b.id
      ORDER BY fm.id ASC
    ''');
    final relationRows = await db.query('relations');

    if (!mounted) return;
    setState(() {
      _layout = _buildLayout(memberRows, relationRows);
      _loading = false;
    });
  }

  _TreeLayout _buildLayout(
    List<Map<String, dynamic>> memberRows,
    List<Map<String, dynamic>> relationRows,
  ) {
    final persons = <_TreePerson>[];
    final byId = <int, _TreePerson>{};

    for (final row in memberRows) {
      final id = row['id'] as int?;
      if (id == null) continue;

      final person = _TreePerson(
        id: id,
        fullName: (row['name'] as String?) ?? '',
        relation: (row['relation'] as String?) ?? '',
        photoPath: row['photo_path'] as String?,
        birthDate: row['bday_date'] as String?,
      );
      persons.add(person);
      byId[id] = person;
    }

    if (persons.isEmpty) {
      return _TreeLayout(
        persons: persons,
        links: <_TreeLink>[],
        positions: <int, Offset>{},
        width: 0,
        height: 0,
      );
    }

    final links = <_TreeLink>[];
    final parentsOf = <int, List<int>>{};
    final spouseOf = <int, List<int>>{};

    for (final row in relationRows) {
      final aId = row['a_id'] as int?;
      final bId = row['b_id'] as int?;
      final type = row['type'] as String?;
      if (aId == null || bId == null || type == null) continue;
      if (!byId.containsKey(aId) || !byId.containsKey(bId)) continue;

      links.add(_TreeLink(fromId: aId, toId: bId, type: type));

      if (type == 'father' || type == 'mother') {
        parentsOf.putIfAbsent(bId, () => <int>[]).add(aId);
      } else if (type == 'spouse') {
        spouseOf.putIfAbsent(aId, () => <int>[]).add(bId);
        spouseOf.putIfAbsent(bId, () => <int>[]).add(aId);
      }
    }

    // --- Поколения: потомки глубже родителей, супруги на одном уровне ---
    final generations = <int, int>{for (final person in persons) person.id: 0};
    final iterations = persons.length + 3;

    for (var step = 0; step < iterations; step++) {
      for (final entry in parentsOf.entries) {
        var maxParent = -1;
        for (final parentId in entry.value) {
          final parentGeneration = generations[parentId] ?? 0;
          if (parentGeneration > maxParent) maxParent = parentGeneration;
        }
        final current = generations[entry.key] ?? 0;
        if (maxParent >= 0 && current < maxParent + 1) {
          generations[entry.key] = maxParent + 1;
        }
      }

      for (final entry in spouseOf.entries) {
        var maxGeneration = 0;
        for (final id in [entry.key, ...entry.value]) {
          final generation = generations[id] ?? 0;
          if (generation > maxGeneration) maxGeneration = generation;
        }
        generations[entry.key] = maxGeneration;
        for (final id in entry.value) {
          generations[id] = maxGeneration;
        }
      }
    }

    // Страховка от циклов: значения не должны «уезжать» в бесконечность.
    final generationLimit = persons.length;
    for (final id in generations.keys.toList()) {
      final generation = generations[id] ?? 0;
      if (generation > generationLimit) {
        generations[id] = 0;
      }
    }

    for (final person in persons) {
      person.generation = generations[person.id] ?? 0;
    }

    // --- Группы супругов, чтобы в ряду они стояли рядом (union-find) ---
    final groupParent = <int, int>{for (final person in persons) person.id: person.id};

    int findRoot(int id) {
      var current = id;
      var guard = 0;
      while (guard++ < 1000) {
        final parent = groupParent[current];
        if (parent == null || parent == current) return current;
        current = parent;
      }
      return current;
    }

    void unite(int first, int second) {
      final rootFirst = findRoot(first);
      final rootSecond = findRoot(second);
      if (rootFirst != rootSecond) groupParent[rootSecond] = rootFirst;
    }

    for (final link in links) {
      if (link.isSpouse) unite(link.fromId, link.toId);
    }

    final byGeneration = <int, List<_TreePerson>>{};
    for (final person in persons) {
      byGeneration.putIfAbsent(person.generation, () => <_TreePerson>[]).add(person);
    }

    var maxRowLength = 0;
    for (final row in byGeneration.values) {
      row.sort((first, second) {
        final rootFirst = findRoot(first.id);
        final rootSecond = findRoot(second.id);
        if (rootFirst != rootSecond) return rootFirst.compareTo(rootSecond);
        return first.id.compareTo(second.id);
      });
      if (row.length > maxRowLength) maxRowLength = row.length;
    }

    // --- Координаты узлов ---
    final positions = <int, Offset>{};
    var maxGeneration = 0;

    for (final entry in byGeneration.entries) {
      final generation = entry.key;
      if (generation > maxGeneration) maxGeneration = generation;

      final row = entry.value;
      for (var index = 0; index < row.length; index++) {
        positions[row[index].id] = Offset(
          _padding + index * (_nodeWidth + _gapX),
          _padding + generation * _rowHeight,
        );
      }
    }

    final width = _padding * 2 + maxRowLength * (_nodeWidth + _gapX) - _gapX;
    final height = _padding * 2 + maxGeneration * _rowHeight + _nodeHeight;

    return _TreeLayout(
      persons: persons,
      links: links,
      positions: positions,
      width: width,
      height: height,
    );
  }

  void _showPersonSheet(_TreePerson person) {
    final birthDate = parseFlexibleDate(person.birthDate);
    final age = ageText(person.birthDate);
    final nextBirthday = nextBirthdayText(person.birthDate);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person.photoPath != null &&
                  File(person.photoPath!).existsSync())
                CircleAvatar(
                  radius: 40,
                  backgroundImage: FileImage(File(person.photoPath!)),
                )
              else
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    person.fullName.isEmpty
                        ? '?'
                        : person.fullName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.teal),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                person.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                person.relation,
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (birthDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '🎂 ${formatShortDate(birthDate)}',
                  style: const TextStyle(fontSize: 15),
                ),
                if (age.isNotEmpty)
                  Text(
                    'Возраст: $age',
                    style: const TextStyle(color: Colors.grey),
                  ),
                if (nextBirthday.isNotEmpty)
                  Text(
                    nextBirthday,
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.card_giftcard),
                label: Text('Wishlist: ${shortName(person.fullName)}'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GiftsScreen(
                        filterForWhom: person.fullName,
                        avatarPath: person.photoPath,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(_TreePerson person) {
    final displayName = shortName(person.fullName);
    final label = displayName.isEmpty ? person.fullName : displayName;
    final age = ageText(person.birthDate);
    final hasPhoto =
        person.photoPath != null && File(person.photoPath!).existsSync();

    return GestureDetector(
      onTap: () => _showPersonSheet(person),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasPhoto)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: FileImage(File(person.photoPath!)),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    label.isEmpty ? '?' : label[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                person.relation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              if (age.isNotEmpty)
                Text(
                  age,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.teal),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHint({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.teal.shade200),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 2,
                  child: ColoredBox(color: Color(0xFF80CBC4)),
                ),
                SizedBox(width: 6),
                Text('родитель → ребёнок', style: TextStyle(fontSize: 11)),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 2,
                  child: ColoredBox(color: Color(0xFFF06292)),
                ),
                SizedBox(width: 6),
                Text('супруг(а)', style: TextStyle(fontSize: 11)),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'щипок — зум, перетаскивание — сдвиг',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(_TreeLayout layout) {
    if (layout.persons.isEmpty) {
      return _buildHint(
        icon: Icons.family_restroom,
        title: 'Древо пока пустое',
        text: 'Добавьте членов семьи на вкладке «Семья», затем откройте '
            'профиль человека и укажите отца, мать и супруга.',
      );
    }

    if (layout.links.isEmpty) {
      return _buildHint(
        icon: Icons.account_tree,
        title: 'Связи ещё не указаны',
        text: 'Откройте карточку человека на вкладке «Семья» → '
            '«Редактировать профиль» и заполните поля «Отец», «Мать», '
            '«Супруг(а)». Древо построится само.',
      );
    }

    return Stack(
      children: [
        InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(200),
          minScale: 0.2,
          maxScale: 2.5,
          child: SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TreePainter(
                      positions: layout.positions,
                      links: layout.links,
                      nodeWidth: _nodeWidth,
                      nodeHeight: _nodeHeight,
                    ),
                  ),
                ),
                ...layout.persons.map((person) {
                  final position = layout.positions[person.id];
                  if (position == null) return const SizedBox.shrink();
                  return Positioned(
                    left: position.dx,
                    top: position.dy,
                    width: _nodeWidth,
                    height: _nodeHeight,
                    child: _buildNode(person),
                  );
                }),
              ],
            ),
          ),
        ),
        Positioned(left: 12, bottom: 12, child: _buildLegend()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Фамильное древо'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTree,
          ),
        ],
      ),
      body: _loading || layout == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(layout),
    );
  }
}

/// Рисует линии связей между узлами дерева.
class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.positions,
    required this.links,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  final Map<int, Offset> positions;
  final List<_TreeLink> links;
  final double nodeWidth;
  final double nodeHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = const Color(0xFF80CBC4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final spousePaint = Paint()
      ..color = const Color(0xFFF06292)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final from = positions[link.fromId];
      final to = positions[link.toId];
      if (from == null || to == null) continue;

      if (link.isSpouse) {
        final y = from.dy + nodeHeight / 2;
        final left = from.dx < to.dx ? from : to;
        final right = from.dx < to.dx ? to : from;
        canvas.drawLine(
          Offset(left.dx + nodeWidth, y),
          Offset(right.dx, y),
          spousePaint,
        );
      } else {
        final start = Offset(from.dx + nodeWidth / 2, from.dy + nodeHeight);
        final end = Offset(to.dx + nodeWidth / 2, to.dy);
        final middleY = start.dy + (end.dy - start.dy) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx, middleY)
          ..lineTo(end.dx, middleY)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, parentPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) {
    return oldDelegate.positions != positions || oldDelegate.links != links;
  }
}
