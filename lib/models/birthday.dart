class Birthday {
  final int? id; final String name; final String date; final String category;
  Birthday({this.id, required this.name, required this.date, required this.category});
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'date': date, 'category': category};
  factory Birthday.fromMap(Map<String, dynamic> map) => Birthday(id: map['id'], name: map['name'], date: map['date'], category: map['category']);
}
