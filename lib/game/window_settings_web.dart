Future<void> initWindowManagerImpl() async {
  // No-op on Web (browser manages window bounds)
}

Future<void> setWindowSizeImpl(double width, double height) async {
  // No-op on Web
}

Future<void> setFullScreenImpl(bool fullscreen) async {
  // No-op on Web
}

Future<bool> isFullScreenImpl() async {
  return false;
}

Future<Map<String, double>> getWindowSizeImpl() async {
  return {'width': 1280, 'height': 720};
}
