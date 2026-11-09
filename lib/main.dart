import 'package:flutter/material.dart';
import 'state/books_controller.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = BooksController();
  await controller.start();
  runApp(HyperionBooksApp(controller: controller));
}

class HyperionBooksApp extends StatelessWidget {
  final BooksController controller;
  const HyperionBooksApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16865B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hyperion Books',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green,
          brightness: Brightness.light, surface: const Color(0xFFF6F8FB)),
        scaffoldBackgroundColor: const Color(0xFFF4F7FA),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white,
          foregroundColor: Color(0xFF102840)),
        cardTheme: CardThemeData(color: Colors.white,
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14)),
      ),
      home: BooksHome(controller: controller),
    );
  }
}
