import 'package:flutter/material.dart';
import 'screens/main_menu.dart';
import 'game/window_settings.dart';
import 'game/audio_synth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindowManager();
  await initAudioEngine();
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
