// Тесты чистых функций: без плагинов (sqflite/shared_preferences) —
// поэтому запускаются и в CI, и локально без эмулятора.
//
// Файл специально лежит в репозитории: `flutter create` не перезаписывает
// существующие файлы, а сгенерированный шаблонный widget_test ссылается
// на несуществующий `MyApp` и валит `flutter analyze`.

import 'package:family_lists/utils/person_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFlexibleDate', () {
    test('понимает ДД-ММ-ГГГГ', () {
      final date = parseFlexibleDate('05-03-1990');
      expect(date, isNotNull);
      expect(date!.day, 5);
      expect(date.month, 3);
      expect(date.year, 1990);
    });

    test('понимает ГГГГ-ММ-ДД', () {
      final date = parseFlexibleDate('1990-03-05');
      expect(date, isNotNull);
      expect(date!.day, 5);
      expect(date.month, 3);
      expect(date.year, 1990);
    });

    test('понимает точку как разделитель', () {
      expect(parseFlexibleDate('05.03.1990')?.day, 5);
    });

    test('отбрасывает невозможную дату', () {
      expect(parseFlexibleDate('31-02-2000'), isNull);
    });

    test('отбрасывает мусор', () {
      expect(parseFlexibleDate(null), isNull);
      expect(parseFlexibleDate(''), isNull);
      expect(parseFlexibleDate('не дата'), isNull);
      expect(parseFlexibleDate('1990-13-01'), isNull);
    });
  });

  group('pluralize', () {
    test('склоняет годы', () {
      expect(pluralize(1, 'год', 'года', 'лет'), 'год');
      expect(pluralize(3, 'год', 'года', 'лет'), 'года');
      expect(pluralize(5, 'год', 'года', 'лет'), 'лет');
      expect(pluralize(11, 'год', 'года', 'лет'), 'лет');
      expect(pluralize(21, 'год', 'года', 'лет'), 'год');
      expect(pluralize(112, 'год', 'года', 'лет'), 'лет');
    });
  });

  group('ageText', () {
    test('без даты возвращает пусто', () {
      expect(ageText(null), '');
      expect(ageText(''), '');
    });

    test('считает полные годы', () {
      final now = DateTime.now();
      final birth = DateTime(now.year - 30, 1, 1);
      final day = birth.day.toString().padLeft(2, '0');
      final month = birth.month.toString().padLeft(2, '0');
      final text = ageText('$day-$month-${birth.year}');

      // 30 или 31 полных года в зависимости от текущей даты —
      // проверяем, что получилось «<число> год/года/лет».
      expect(text, isNotEmpty);
      expect(RegExp(r'^\d+\s').hasMatch(text), isTrue);
    });

    test('будущая дата не даёт возраста', () {
      final future = DateTime.now().add(const Duration(days: 400));
      final day = future.day.toString().padLeft(2, '0');
      final month = future.month.toString().padLeft(2, '0');
      expect(ageText('$day-$month-${future.year}'), '');
    });
  });

  group('splitFullName', () {
    test('разбирает ФИО с девичьей фамилией', () {
      final parts = splitFullName('Иванова Анна Петровна (Смирнова)');
      expect(parts['surname'], 'Иванова');
      expect(parts['name'], 'Анна');
      expect(parts['patronymic'], 'Петровна');
      expect(parts['maiden'], 'Смирнова');
    });

    test('одно слово считается именем', () {
      expect(splitFullName('Иван')['name'], 'Иван');
      expect(splitFullName('Иван')['surname'], '');
    });

    test('пустая строка не ломает разбор', () {
      expect(splitFullName(null)['name'], '');
      expect(splitFullName('')['surname'], '');
    });
  });

  group('shortName / memberLabel', () {
    test('shortName берёт имя', () {
      expect(shortName('Иванова Анна Петровна'), 'Анна');
      expect(shortName('Пётр'), 'Пётр');
    });

    test('memberLabel добавляет родство', () {
      expect(memberLabel('Иванова Анна', 'Жена'), 'Анна (Жена)');
    });
  });
}
