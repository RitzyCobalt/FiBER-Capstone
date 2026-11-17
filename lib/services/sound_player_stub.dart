import 'package:flutter/services.dart';

const MethodChannel _audioChannel = MethodChannel('fiber_audio');

void playWebDataUri(String dataUri, {double volume = 0.5}) {
  _audioChannel.invokeMethod('playDataUri', < String, dynamic >{
    'dataUri': dataUri,
    'volume': volume,
  }).catchError((_) {});
}