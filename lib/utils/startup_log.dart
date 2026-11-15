import 'package:flutter/foundation.dart';

/// Журнал проблем запуска.
///
/// Идея: если что-то падает при инициализации (миграция базы, плагины
/// уведомлений, синхронизация), приложение всё равно стартует, а текст ошибки
/// попадает сюда — его видно в «Настройки → Диагностика» и можно прислать
/// разработчику без logcat.
class StartupLog {
  StartupLog._();

  static final List<String> _messages = <String>[];

  static List<String> get messages => List<String>.unmodifiable(_messages);

  static bool get hasProblems => _messages.isNotEmpty;

  /// Записывает ошибку в формате «Раздел: текст ошибки».
  static void add(String section, Object error) {
    final text = '$section: $error';
    if (_messages.contains(text)) return;
    _messages.add(text);
    debugPrint('STARTUP ERROR $text');
  }

  static void info(String text) {
    if (_messages.contains(text)) return;
    _messages.add(text);
    debugPrint('STARTUP INFO $text');
  }

  static void clear() => _messages.clear();
}
