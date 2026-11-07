import 'package:flutter/material.dart';

class ItemTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const ItemTile({super.key, required this.title, required this.subtitle, required this.isCompleted, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(title + subtitle),
      direction: DismissDirection.endToStart,
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: Checkbox(value: isCompleted, onChanged: (_) => onToggle()),
          title: Text(title, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null, color: isCompleted ? Colors.grey : null)),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}
