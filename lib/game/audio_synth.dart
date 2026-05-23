import 'audio_synth_stub.dart'
    if (dart.library.js) 'audio_synth_web.dart' as impl;

void playSfx(String name, double volume) {
  impl.playSfxImpl(name, volume);
}
