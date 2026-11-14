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

  static Future<void> init() async {
    if (_initialized) return;

    _initTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
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
