class Purchase {
  final int? id; final String title; final String category; final String periodicity; bool isCompleted;
  Purchase({this.id, required this.title, required this.category, required this.periodicity, this.isCompleted = false});
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'category': category, 'periodicity': periodicity, 'isCompleted': isCompleted ? 1 : 0};
  factory Purchase.fromMap(Map<String, dynamic> map) => Purchase(id: map['id'], title: map['title'], category: map['category'], periodicity: map['periodicity'], isCompleted: map['isCompleted'] == 1);
}
