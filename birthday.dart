class Birthday {
  final int? id;
  final String name;
  final String date;
  final String category;
  final int remindDays;
  final String? photoPath; // Вот это поле мы потеряли

  Birthday({
    this.id, 
    required this.name, 
    required this.date, 
    required this.category, 
    this.remindDays = 1,
    this.photoPath
  });

  Map<String, dynamic> toMap() => {
    'id': id, 
    'name': name, 
    'date': date, 
    'category': category, 
    'remind_days': remindDays,
    'photo_path': photoPath
  };
  
  factory Birthday.fromMap(Map<String, dynamic> map) => Birthday(
    id: map['id'], 
    name: map['name'], 
    date: map['date'], 
    category: map['category'], 
    remindDays: map['remind_days'] ?? 1,
    photoPath: map['photo_path']
  );
}
