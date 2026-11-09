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
  final VoidCallback? onShowStats; // Кнопка перехода к графику

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

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(title + subtitle),
      // Свайп влево (удаление)
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Удалить',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      // Свайп вправо (редактирование)
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
          onTap: onEdit, 
          leading: Checkbox(value: isCompleted, onChanged: (_) => onToggle()),
          title: Row(
            children: [
              // Иконка лампочки для счетчиков
              if (readingValue != null) 
                const Icon(Icons.lightbulb, size: 18, color: Colors.orange),
              if (readingValue != null) 
                const SizedBox(width: 6),
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
              Text(
                subtitle, 
                style: TextStyle(color: isOverdue && !isCompleted ? Colors.red.shade300 : null)
              ),
              // Показываем последние введенные показания
              if (readingValue != null)
                Text(
                  'Показания: $readingValue', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)
                ),
            ],
          ),
          // Кнопка графика (появляется только если это счетчик)
          trailing: readingValue != null && onShowStats != null
              ? IconButton(
                  icon: const Icon(Icons.bar_chart, color: Colors.teal),
                  tooltip: 'Статистика потребления',
                  onPressed: onShowStats,
                )
              : null,
        ),
      ),
    );
  }
}
