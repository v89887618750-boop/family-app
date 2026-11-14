class Task {
  final int? id;
  final String title;
  final String category;
  final String periodicity;
  bool isCompleted;
  String? dueDate;
  String? dueTime;
  String? readingValue;

  Task({
    this.id, 
    required this.title, 
    required this.category, 
    required this.periodicity, 
    this.isCompleted = false,
    this.dueDate,
    this.dueTime,
    this.readingValue,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 
    'title': title, 
    'category': category, 
    'periodicity': periodicity, 
    'isCompleted': isCompleted ? 1 : 0,
    'due_date': dueDate,
    'due_time': dueTime,
    'reading_value': readingValue,
  };
  
  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'], 
    title: map['title'], 
    category: map['category'], 
    periodicity: map['periodicity'], 
    isCompleted: map['isCompleted'] == 1,
    dueDate: map['due_date'],
    dueTime: map['due_time'],
    readingValue: map['reading_value'],
  );
}
