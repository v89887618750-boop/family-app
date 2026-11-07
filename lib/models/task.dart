class Task {
  final int? id; final String title; final String category; final String periodicity; bool isCompleted;
  Task({this.id, required this.title, required this.category, required this.periodicity, this.isCompleted = false});
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'category': category, 'periodicity': periodicity, 'isCompleted': isCompleted ? 1 : 0};
  factory Task.fromMap(Map<String, dynamic> map) => Task(id: map['id'], title: map['title'], category: map['category'], periodicity: map['periodicity'], isCompleted: map['isCompleted'] == 1);
}
