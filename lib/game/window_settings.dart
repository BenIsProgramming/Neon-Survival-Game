import 'window_settings_desktop.dart'
    if (dart.library.js) 'window_settings_web.dart' as impl;

Future<void> initWindowManager() async {
  await impl.initWindowManagerImpl();
}

Future<void> setWindowSize(double width, double height) async {
  await impl.setWindowSizeImpl(width, height);
}

Future<void> setFullScreen(bool fullscreen) async {
  await impl.setFullScreenImpl(fullscreen);
}

Future<bool> isFullScreen() async {
  return await impl.isFullScreenImpl();
}

Future<Map<String, double>> getWindowSize() async {
  return await impl.getWindowSizeImpl();
}
