import 'package:flutter/material.dart';
import 'tasks_screen.dart';
import 'purchases_screen.dart';
import 'birthdays_screen.dart';
import 'gifts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const TasksScreen(),
    const PurchasesScreen(),
    const BirthdaysScreen(),
    const GiftsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.task), label: 'Дела'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Покупки'),
          NavigationDestination(icon: Icon(Icons.cake), label: 'Дни рождения'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Подарки'),
        ],
      ),
    );
  }
}
