import 'dart:convert';

class Purchase {
  final int? id;
  final String title;
  final String category;
  final String periodicity;
  bool isCompleted;
  List<String> itemsList; // Список продуктов

  Purchase({
    this.id, 
    required this.title, 
    required this.category, 
    required this.periodicity, 
    this.isCompleted = false, 
    this.itemsList = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id, 
    'title': title, 
    'category': category, 
    'periodicity': periodicity, 
    'isCompleted': isCompleted ? 1 : 0, 
    'note': jsonEncode(itemsList) // Сохраняем как JSON-строку
  };
  
  factory Purchase.fromMap(Map<String, dynamic> map) {
    List<String> items = [];
    if (map['note'] != null) {
      try {
        final decoded = jsonDecode(map['note']);
        if (decoded is List) {
          items = List<String>.from(decoded);
        }
      } catch (e) {
        // Если старый формат (текст), просто добавляем как один пункт
        items = [map['note']];
      }
    }
    
    return Purchase(
      id: map['id'], 
      title: map['title'], 
      category: map['category'], 
      periodicity: map['periodicity'], 
      isCompleted: map['isCompleted'] == 1,
      itemsList: items,
    );
  }
}
