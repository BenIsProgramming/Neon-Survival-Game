import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initWindowManagerImpl() async {
  await windowManager.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final double width = prefs.getDouble('neon_settings_window_width') ?? 1280;
  final double height = prefs.getDouble('neon_settings_window_height') ?? 720;
  final bool fullscreen = prefs.getBool('neon_settings_fullscreen') ?? false;

  WindowOptions windowOptions = WindowOptions(
    size: Size(width, height),
    minimumSize: const Size(800, 600),
    center: true,
    title: 'Neon Survival',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setFullScreen(fullscreen);
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> setWindowSizeImpl(double width, double height) async {
  await windowManager.setSize(Size(width, height));
  await windowManager.center();
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('neon_settings_window_width', width);
  await prefs.setDouble('neon_settings_window_height', height);
}

Future<void> setFullScreenImpl(bool fullscreen) async {
  await windowManager.setFullScreen(fullscreen);
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('neon_settings_fullscreen', fullscreen);
}

Future<bool> isFullScreenImpl() async {
  return await windowManager.isFullScreen();
}

Future<Map<String, double>> getWindowSizeImpl() async {
  final size = await windowManager.getSize();
  return {'width': size.width, 'height': size.height};
}
