import 'audio_synth_desktop.dart'
    if (dart.library.js) 'audio_synth_web.dart' as impl;

void playSfx(String name, double volume) {
  impl.playSfxImpl(name, volume);
}

Future<void> initAudioEngine() async {
  await impl.initAudioEngineImpl();
}
