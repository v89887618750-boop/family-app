import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'purchases_screen.dart';
import 'birthdays_screen.dart';
import 'gifts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final Function(double) onFontSizeChanged; // Новая функция

  const HomeScreen({
    super.key, 
    required this.onThemeChanged,
    required this.onFontSizeChanged,
  });

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
      const BirthdaysScreen(),
      const GiftsScreen(),
      SettingsScreen(
        onThemeChanged: widget.onThemeChanged,
        onFontSizeChanged: widget.onFontSizeChanged, // Передаем дальше
      ),
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
          NavigationDestination(icon: Icon(Icons.cake), label: 'Дни рождения'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Подарки'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
