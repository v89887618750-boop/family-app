import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/registration_screen.dart';
import 'sync/sync_service.dart';
import 'utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Синхронизация работает на чистом HTTP (без нативных плагинов).
  // Если при сборке не передали ключи — приложение полностью локальное.
  await SyncService.init();

  await NotificationService.init();

  // Запрос разрешения на уведомления для Android 13+.
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(const FamilyListsApp());
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
