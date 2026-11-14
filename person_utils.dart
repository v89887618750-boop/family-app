// Общие помощники для работы с людьми семьи: даты, возраст и ФИО.
//
// Даты в приложении встречаются в двух форматах:
//   * ДД-ММ-ГГГГ — так пишет само приложение (birthdays, family_members);
//   * ГГГГ-ММ-ДД — ISO-формат (дела, показания счётчиков).

/// Разбирает дату в любом из поддерживаемых форматов.
/// Возвращает `null`, если строка пустая или дата невозможна (например, 31 февраля).
DateTime? parseFlexibleDate(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;

  final parts = value.split(RegExp(r'[-./]'));
  if (parts.length != 3) return null;

  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  final third = int.tryParse(parts[2]);
  if (first == null || second == null || third == null) return null;

  final int day;
  final int month;
  final int year;

  if (parts[0].length == 4) {
    year = first;
    month = second;
    day = third;
  } else {
    day = first;
    month = second;
    year = third;
  }

  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final date = DateTime(year, month, day);
  if (date.day != day || date.month != month || date.year != year) {
    return null;
  }
  return date;
}

/// `ДД.ММ.ГГГГ` — для показа пользователю.
String formatShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// `ДД-ММ-ГГГГ` — формат хранения в таблице `birthdays`.
String storageDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day-$month-${date.year}';
}

/// Склонение существительного по числу: `pluralize(3, 'год', 'года', 'лет')`.
String pluralize(int value, String one, String few, String many) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

/// Возраст словами: «32 года», «8 месяцев», «12 дней».
/// Пустая строка, если даты нет или она в будущем.
String ageText(String? rawDate) {
  final birthDate = parseFlexibleDate(rawDate);
  if (birthDate == null) return '';

  final now = DateTime.now();
  if (birthDate.isAfter(now)) return '';

  int years = now.year - birthDate.year;
  int months = now.month - birthDate.month;
  if (now.day < birthDate.day) months -= 1;
  if (months < 0) {
    years -= 1;
    months += 12;
  }

  if (years < 0) return '';
  if (years >= 1) return '$years ${pluralize(years, 'год', 'года', 'лет')}';
  if (months >= 1) {
    return '$months ${pluralize(months, 'месяц', 'месяца', 'месяцев')}';
  }

  final days = now.difference(birthDate).inDays;
  return '$days ${pluralize(days, 'день', 'дня', 'дней')}';
}

/// «Сегодня!», «Завтра», «через 12 дней» — ближайший день рождения.
String nextBirthdayText(String? rawDate) {
  final birthDate = parseFlexibleDate(rawDate);
  if (birthDate == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var next = DateTime(now.year, birthDate.month, birthDate.day);
  if (next.isBefore(today)) {
    next = DateTime(now.year + 1, birthDate.month, birthDate.day);
  }

  final days = next.difference(today).inDays;
  if (days == 0) return '🎉 Сегодня!';
  if (days == 1) return 'Завтра';
  return 'через $days ${pluralize(days, 'день', 'дня', 'дней')}';
}

/// Разбирает ФИО на составляющие.
///
/// Понимает «Иванова Анна Петровна (Смирнова)», «Иван»,
/// а девичью фамилию в скобках выносит в отдельное поле.
Map<String, String> splitFullName(String? fullName) {
  var rest = (fullName ?? '').trim();
  var maiden = '';

  final maidenMatch = RegExp(r'\(([^)]*)\)\s*$').firstMatch(rest);
  if (maidenMatch != null) {
    maiden = maidenMatch.group(1)?.trim() ?? '';
    rest = rest.substring(0, maidenMatch.start).trim();
  }

  final parts = rest.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  final result = <String, String>{
    'surname': '',
    'name': '',
    'patronymic': '',
    'maiden': maiden,
  };

  if (parts.length >= 2) {
    result['surname'] = parts[0];
    result['name'] = parts[1];
    if (parts.length > 2) {
      result['patronymic'] = parts.sublist(2).join(' ');
    }
  } else if (parts.length == 1) {
    result['name'] = parts[0];
  }

  return result;
}

/// Только имя — для подписей и аватаров.
String shortName(String? fullName) {
  final parsed = splitFullName(fullName);
  final name = parsed['name'] ?? '';
  if (name.isNotEmpty) return name;
  return parsed['surname'] ?? '';
}

/// Короткая подпись для выпадающих списков: «Анна (Жена)».
String memberLabel(String? fullName, String relation) {
  final name = shortName(fullName);
  if (name.isEmpty) return relation;
  return '$name ($relation)';
}
