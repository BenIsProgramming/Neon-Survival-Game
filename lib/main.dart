import 'package:flutter/material.dart';
import 'screens/main_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeonSurvivalApp());
}

class NeonSurvivalApp extends StatelessWidget {
  const NeonSurvivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Survival',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF04060C),
        fontFamily: 'monospace', // Gives a clean digital arcade typography look
      ),
      home: const MainMenuScreen(),
    );
  }
}
