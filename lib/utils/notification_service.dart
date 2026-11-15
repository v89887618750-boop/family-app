import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Локальные напоминания (о делах и показаниях счётчиков).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Возможные имена иконки: у сборки может быть как `ic_launcher`,
  /// так и `launcher_icon` (flutter_launcher_icons в pubspec).
  /// Перебираем по очереди — если ресурса нет, плагин бросает исключение,
  /// и раньше это убивало приложение на старте.
  static const List<String> _iconCandidates = <String>[
    '@mipmap/ic_launcher',
    '@mipmap/launcher_icon',
    'ic_launcher',
    'launcher_icon',
  ];

  static Future<void> init() async {
    if (_initialized) return;

    _initTimeZone();

    Object? lastError;
    for (final icon in _iconCandidates) {
      try {
        await _plugin.initialize(
          InitializationSettings(
            android: AndroidInitializationSettings(icon),
          ),
        );
        _initialized = true;
        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('не удалось инициализировать уведомления: $lastError');
  }

  /// timezone по умолчанию берёт UTC — из-за этого напоминания приходили
  /// со сдвигом на часовой пояс. Подбираем зону с текущим смещением устройства.
  static void _initTimeZone() {
    tzdata.initializeTimeZones();
    try {
      final deviceOffset = DateTime.now().timeZoneOffset.inMilliseconds;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (location.currentTimeZone.offset == deviceOffset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (e) {
      debugPrint('Не удалось определить часовой пояс: $e');
    }
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'family_channel',
    'Семейные напоминания',
    channelDescription: 'Уведомления о делах и днях рождения',
    importance: Importance.max,
    priority: Priority.high,
  );

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await init();

    final when = tz.TZDateTime.from(scheduledDate, tz.local);
    const details = NotificationDetails(android: _androidDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // В flutter_local_notifications 17.x этот параметр обязательный.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      // На Android 12+ может не быть разрешения на точные будильники.
      debugPrint('Точное уведомление недоступно ($e), ставим обычное.');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
