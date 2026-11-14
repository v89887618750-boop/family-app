/// Желание из семейного Wishlist.
class Gift {
  final int? id;
  final String title;
  final String forWhom;
  final String category;
  bool isBought;
  String? note;
  String? photoPath;
  String? reservedBy;

  Gift({
    this.id,
    required this.title,
    required this.forWhom,
    required this.category,
    this.isBought = false,
    this.note,
    this.photoPath,
    this.reservedBy,
  });

  /// Карта для вставки/обновления в таблице `gifts`.
  ///
  /// ВАЖНО: по умолчанию `id` НЕ попадает в карту. Иначе при обновлении
  /// существующей записи мы бы отправляли `{"id": null}` и SQLite падал
  /// (нельзя записать NULL в PRIMARY KEY) — из-за этого ломалось сохранение
  /// Wishlist. Для вставки включать id не нужно вообще.
  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'title': title,
      'forWhom': forWhom,
      'category': category,
      'isBought': isBought ? 1 : 0,
      'note': note,
      'photo_path': photoPath,
      'reserved_by': reservedBy,
    };
    if (includeId && id != null) {
      map['id'] = id;
    }
    return map;
  }

  Gift copyWith({
    int? id,
    String? title,
    String? forWhom,
    String? category,
    bool? isBought,
    String? note,
    String? photoPath,
    String? reservedBy,
  }) {
    return Gift(
      id: id ?? this.id,
      title: title ?? this.title,
      forWhom: forWhom ?? this.forWhom,
      category: category ?? this.category,
      isBought: isBought ?? this.isBought,
      note: note ?? this.note,
      photoPath: photoPath ?? this.photoPath,
      reservedBy: reservedBy ?? this.reservedBy,
    );
  }

  factory Gift.fromMap(Map<String, dynamic> map) {
    return Gift(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      forWhom: (map['forWhom'] as String?) ?? 'Общее',
      category: (map['category'] as String?) ?? 'Подарок',
      isBought: map['isBought'] == 1 || map['isBought'] == true,
      note: map['note'] as String?,
      photoPath: map['photo_path'] as String?,
      reservedBy: map['reserved_by'] as String?,
    );
  }
}
