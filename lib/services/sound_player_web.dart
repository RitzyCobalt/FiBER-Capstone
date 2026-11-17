// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void playWebDataUri(String dataUri, {double volume = 0.5}) {
  try {
    final audio = html.AudioElement(dataUri);
    audio.volume = volume.clamp(0.0, 1.0);
    audio.play();
  } catch (_) {}
}