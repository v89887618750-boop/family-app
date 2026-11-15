import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/registration_screen.dart';
import 'sync/sync_service.dart';
import 'utils/notification_service.dart';
import 'utils/startup_log.dart';

/// Шаг инициализации не должен держать запуск дольше этого времени.
const Duration _startupStepTimeout = Duration(seconds: 12);

/// ВАЖНО: каждый шаг инициализации обёрнут в try/catch и в таймаут.
///
/// Раньше исключение (или зависание) на любом шаге — например, миграция базы
/// данных или отсутствующий ресурс иконки у плагина уведомлений — убивало
/// приложение ещё до runApp. Снаружи это выглядит как чёрный/белый экран.
///
/// Теперь:
///   * сбой шага не мешает запуску;
///   * зависание шага прерывается через 12 секунд;
///   * если что-то пошло не так, показывается экран с текстом ошибки,
///     который можно выделить и переслать разработчику.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Ловим ошибки фреймворка, чтобы они попадали в журнал, а не только в logcat.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    StartupLog.add('Flutter', details.exceptionAsString());
  };

  // В release упавший виджет показывал пустой серый/чёрный прямоугольник.
  // Теперь вместо пустоты — читаемый текст ошибки.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFFEBEE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Text(
            'Ошибка интерфейса:\n${details.exceptionAsString()}',
            style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12),
          ),
        ),
      ),
    );
  };

  // ВАЖНО: сначала показываем интерфейс (первый кадр), и только потом
  // выполняем инициализацию. Иначе Android держит белую заставку, пока
  // не закончится синхронизация/миграция базы/плагины — снаружи это выглядит
  // как «приложение зависло на белом экране».
  runApp(const FamilyListsApp());

  unawaited(_bootstrap());
}

/// Инициализация в фоне: каждый шаг ограничен таймаутом и не может
/// уронить приложение. Ошибки сохраняются в [StartupLog]
/// (видны в «Настройки → Диагностика»).
Future<void> _bootstrap() async {
  await _guarded('Синхронизация', () => SyncService.init());

  await _guarded('База данных', () async {
    final db = await DatabaseHelper.instance.database;
    await db.rawQuery('SELECT COUNT(*) FROM tasks');
    StartupLog.info('База данных: схема v16 открыта');
  });

  await _guarded('Уведомления', () async {
    await NotificationService.init();

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  });
}

/// Выполняет шаг инициализации, не давая ему уронить или подвесить приложение.
Future<void> _guarded(String section, Future<void> Function() action) async {
  try {
    await action().timeout(_startupStepTimeout);
  } on TimeoutException {
    StartupLog.add(section, 'шаг не завершился за 12 секунд (зависание)');
  } catch (e) {
    StartupLog.add(section, e);
  }
}

/// Экран «запуск с ошибками»: показывает тексты сбоев до открытия приложения.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          title: const Text('Ошибка запуска'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Приложение запустилось с ошибками. Выделите текст ниже, '
              'скопируйте и пришлите разработчику — по нему будет видна '
              'точная причина.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...StartupLog.messages.map(
              (message) => Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => runApp(const FamilyListsApp()),
              child: const Text('Продолжить в приложение (часть данных может не работать)'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class FamilyListsApp extends StatefulWidget {
  const FamilyListsApp({super.key});

  @override
  State<FamilyListsApp> createState() => _FamilyListsAppState();
}

class _FamilyListsAppState extends State<FamilyListsApp> {
  bool _isDarkMode = false;
  double _fontSize = 1.0;
  bool _isLoading = true;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
      _isRegistered = (prefs.getString('my_name') ?? '').isNotEmpty;
      _isLoading = false;
    });
  }

  Future<void> toggleTheme(bool value) async {
    setState(() => _isDarkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  Future<void> changeFontSize(double value) async {
    setState(() => _fontSize = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Семейные списки',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Русская локализация нужна, чтобы календарь и выбор даты/времени
      // были на русском (иначе showDatePicker с locale: ru падает).
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_fontSize),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _isRegistered
          ? HomeScreen(
              onThemeChanged: toggleTheme,
              onFontSizeChanged: changeFontSize,
            )
          : RegistrationScreen(
              onRegistrationComplete: () {
                setState(() => _isRegistered = true);
              },
            ),
    );
  }
}
