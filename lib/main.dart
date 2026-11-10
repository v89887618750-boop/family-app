import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FamilyListsApp());
}

class FamilyListsApp extends StatefulWidget {
  const FamilyListsApp({super.key});

  @override
  State<FamilyListsApp> createState() => _FamilyListsAppState();
}

class _FamilyListsAppState extends State<FamilyListsApp> {
  bool _isDarkMode = false;
  double _fontSize = 1.0; // Коэффициент шрифта

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
    });
  }

  void toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() {
      _isDarkMode = value;
    });
  }

  // Функция для смены шрифта из настроек
  void changeFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', value);
    setState(() {
      _fontSize = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Семейные списки',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Оборачиваем в MediaQuery, чтобы менять размер текста во всем приложении
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_fontSize), // Применяем масштаб
          ),
          child: child!,
        );
      },
      home: HomeScreen(
        onThemeChanged: toggleTheme,
        onFontSizeChanged: changeFontSize, // Передаем функцию шрифта
      ),
    );
  }
}
