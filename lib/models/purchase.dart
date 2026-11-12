class Purchase {
  final int? id;
  final String title;
  final String category;
  final String periodicity;
  bool isCompleted;
  String? note;
  String? familyId; // <-- ДОБАВЛЕНО: ID семьи

  Purchase({
    this.id, 
    required this.title, 
    required this.category, 
    required this.periodicity, 
    this.isCompleted = false, 
    this.note,
    this.familyId,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 
    'title': title, 
    'category': category, 
    'periodicity': periodicity, 
    'isCompleted': isCompleted ? 1 : 0, 
    'note': note,
    'family_id': familyId, // <-- Передаем в базу
  };
  
  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(
    id: map['id'], 
    title: map['title'], 
    category: map['category'], 
    periodicity: map['periodicity'], 
    isCompleted: map['isCompleted'] == 1,
    note: map['note'],
    familyId: map['family_id'], // <-- Читаем из базы
  );
}
