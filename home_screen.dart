import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'purchases_screen.dart';
import 'family_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart'; // <-- Импортируем дашборд

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(double) onFontSizeChanged;

  const HomeScreen({super.key, required this.onThemeChanged, required this.onFontSizeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: (index) {
        setState(() {
          _currentIndex = index;
        });
      }), // 0: Дашборд
      const TasksScreen(),      // 1: Дела
      const PurchasesScreen(),  // 2: Покупки
      const FamilyScreen(),     // 3: Семья
      const NotesScreen(),      // 4: Заметки
      SettingsScreen(onThemeChanged: widget.onThemeChanged, onFontSizeChanged: widget.onFontSizeChanged), // 5: Настройки
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.task), label: 'Дела'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Покупки'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: 'Семья'),
          NavigationDestination(icon: Icon(Icons.note), label: 'Заметки'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
