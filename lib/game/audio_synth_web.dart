import 'dart:js' as js;

void playSfxImpl(String name, double volume) {
  try {
    js.context.callMethod(name, [volume]);
  } catch (_) {}
}

Future<void> initAudioEngineImpl() async {
  // No-op on Web (initialized on user gesture)
}
