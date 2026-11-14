import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ItemTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isOverdue;
  final String? readingValue;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onShowStats;

  const ItemTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isOverdue = false,
    this.readingValue,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onShowStats,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Вы уверены, что хотите удалить "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(title + subtitle),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => _confirmDelete(context), 
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Удалить',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Изменить',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          onTap: onEdit, // <-- ВОТ ОНА, ПРИВЯЗКА К РЕДАКТОРУ
          leading: Checkbox(value: isCompleted, onChanged: (_) => onToggle()),
          title: Row(
            children: [
              if (readingValue != null) const Icon(Icons.lightbulb, size: 18, color: Colors.orange),
              if (readingValue != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : (isOverdue ? Colors.red : null),
                    fontWeight: isOverdue && !isCompleted ? FontWeight.bold : null,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: TextStyle(color: isOverdue && !isCompleted ? Colors.red.shade300 : null)),
              if (readingValue != null)
                Text('Показания: $readingValue', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          trailing: readingValue != null && onShowStats != null
              ? IconButton(
                  icon: const Icon(Icons.bar_chart, color: Colors.teal),
                  onPressed: onShowStats,
                )
              : null,
        ),
      ),
    );
  }
}
