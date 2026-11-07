import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
void main() { runApp(const FamilyListsApp()); }
class FamilyListsApp extends StatelessWidget {
  const FamilyListsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Семейные списки',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
