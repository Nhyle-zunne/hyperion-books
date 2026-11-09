import 'package:flutter/material.dart';
import 'state/books_controller.dart';
import 'theme/hyperion_theme.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the appearance before displaying the first frame.
  await HyperionThemeController.instance.load();
  final controller = BooksController();
  await controller.start();
  runApp(HyperionBooksApp(controller: controller));
}

class HyperionBooksApp extends StatelessWidget {
  final BooksController controller;
  const HyperionBooksApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: HyperionThemeController.instance,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hyperion Books',
      themeMode: HyperionThemeController.instance.mode,
      theme: HyperionColors.buildTheme(Brightness.light),
      darkTheme: HyperionColors.buildTheme(Brightness.dark),
      home: BooksHome(controller: controller),
    ),
  );
}
