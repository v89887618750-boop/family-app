class Gift {
  final int? id;
  final String title;
  final String forWhom;
  final String category;
  bool isBought;
  String? note;
  String? photoPath;

  Gift({
    this.id, 
    required this.title, 
    required this.forWhom, 
    required this.category, 
    this.isBought = false, 
    this.note, 
    this.photoPath
  });

  Map<String, dynamic> toMap() => {
    'id': id, 
    'title': title, 
    'forWhom': forWhom, 
    'category': category, 
    'isBought': isBought ? 1 : 0, 
    'note': note, 
    'photo_path': photoPath
  };
  
  factory Gift.fromMap(Map<String, dynamic> map) => Gift(
    id: map['id'], 
    title: map['title'], 
    forWhom: map['forWhom'], 
    category: map['category'], 
    isBought: map['isBought'] == 1, 
    note: map['note'], 
    photoPath: map['photo_path']
  );
}
