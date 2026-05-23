import 'dart:js' as js;

void playSfxImpl(String name, double volume) {
  try {
    js.context.callMethod(name, [volume]);
  } catch (_) {}
}
