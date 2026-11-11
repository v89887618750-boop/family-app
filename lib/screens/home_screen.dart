import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'purchases_screen.dart';
import 'family_screen.dart';
import 'notes_screen.dart'; // Новый экран
import 'settings_screen.dart';

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
      const TasksScreen(),
      const PurchasesScreen(),
      const FamilyScreen(),
      const NotesScreen(), // <-- ЭКРАН ЗАМЕТОК
      SettingsScreen(onThemeChanged: widget.onThemeChanged, onFontSizeChanged: widget.onFontSizeChanged),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.task), label: 'Дела'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Покупки'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: 'Семья'),
          NavigationDestination(icon: Icon(Icons.note), label: 'Заметки'), // <-- Иконка заметок
          NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
