import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'sound_player_stub.dart'
    if (dart.library.html) 'sound_player_web.dart';

/// Cross-platform sound effects & optional background music controller for Word Hunt.
class SoundService {
  static bool soundEffectsEnabled = true;
  static bool bgmEnabled = false;
  static bool vibrationEnabled = true;
  static Timer? _bgmTimer;
  static int _bgmStep = 0;

  static const List< double > _bgmNotes = [
    261.63, // C4
    329.63, // E4
    392.00, // G4
    523.25, // C5
    392.00, // G4
    329.63, // E4
  ];

  static void applySavedSettings({
    bool? bgm,
    bool? sfx,
    bool? vibration,
  }) {
    if (sfx != null) soundEffectsEnabled = sfx;
    if (vibration != null) vibrationEnabled = vibration;
    if (bgm != null) {
      bgmEnabled = bgm;
      if (bgmEnabled) {
        _startBgmLoop();
      } else {
        stopBgm();
      }
    }
  }

  static void toggleSoundEffects() {
    soundEffectsEnabled = !soundEffectsEnabled;
    if (soundEffectsEnabled) {
      playTap();
    }
  }

  static void toggleBgm() {
    bgmEnabled = !bgmEnabled;
    if (bgmEnabled) {
      _startBgmLoop();
    } else {
      stopBgm();
    }
  }

  static void toggleVibration() {
    vibrationEnabled = !vibrationEnabled;
    if (vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void startBgmIfNeeded() {
    if (bgmEnabled && (_bgmTimer == null || !_bgmTimer!.isActive)) {
      _startBgmLoop();
    }
  }

  static void _startBgmLoop() {
    _bgmTimer?.cancel();
    _bgmStep = 0;
    _playBgmNote();
    _bgmTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (!bgmEnabled) {
        stopBgm();
        return;
      }
      _playBgmNote();
    });
  }

  static void _playBgmNote() {
    if (!bgmEnabled) return;
    final freq = _bgmNotes[_bgmStep % _bgmNotes.length];
    _bgmStep++;
    playWebDataUri(buildToneDataUri(freq, 220), volume: 0.16);
  }

  static void stopBgm() {
    _bgmTimer?.cancel();
    _bgmTimer = null;
  }

  static void triggerWrongVibration() {
    if (!vibrationEnabled) return;
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();
  }

  static void playTap() {
    if (soundEffectsEnabled) {
      playWebDataUri(buildToneDataUri(520, 45), volume: 0.25);
      SystemSound.play(SystemSoundType.click);
    }
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  static void playCorrectWord() {
    if (soundEffectsEnabled) {
      playWebDataUri(
        buildMelodyDataUri([523.25, 659.25, 783.99], 90),
        volume: 0.45,
      );
      SystemSound.play(SystemSoundType.click);
    }
    if (vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void playWrongWord() {
    if (soundEffectsEnabled) {
      playWebDataUri(
        buildMelodyDataUri([260.0, 195.0], 120),
        volume: 0.4,
      );
      SystemSound.play(SystemSoundType.alert);
    }
    triggerWrongVibration();
  }

  static void playLevelUnlock() {
    if (soundEffectsEnabled) {
      playWebDataUri(
        buildMelodyDataUri([440.0, 554.37, 659.25, 880.0], 95),
        volume: 0.48,
      );
    }
    if (vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  static void playGameComplete() {
    if (soundEffectsEnabled) {
      playWebDataUri(
        buildMelodyDataUri([523.25, 659.25, 783.99, 1046.50], 110),
        volume: 0.5,
      );
      SystemSound.play(SystemSoundType.click);
    }
    if (vibrationEnabled) {
      HapticFeedback.vibrate();
    }
  }

  static String buildToneDataUri(double freqHz, int durationMs) {
    return buildMelodyDataUri([freqHz], durationMs);
  }

  /// Generates a valid in-memory WAV data URI for a sequence of notes (arpeggio/chime).
  static String buildMelodyDataUri(List< double > freqs, int noteDurationMs) {
    const sampleRate = 22050;
    final samplesPerNote = (sampleRate * noteDurationMs) ~/ 1000;
    final totalSamples = samplesPerNote * freqs.length;
    final byteCount = totalSamples * 2;
    final buffer = ByteData(44 + byteCount);

    void writeString(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    buffer.setUint32(4, 36 + byteCount, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    buffer.setUint32(40, byteCount, Endian.little);

    for (int n = 0; n < freqs.length; n++) {
      final freqHz = freqs[n];
      final startSample = n * samplesPerNote;
      for (int i = 0; i < samplesPerNote; i++) {
        final t = i / sampleRate;
        final envelope = 1.0 - (i / samplesPerNote);
        final sample = (sin(2 * pi * freqHz * t) * 10000 * envelope).round();
        buffer.setInt16(44 + (startSample + i) * 2, sample, Endian.little);
      }
    }

    return 'data:audio/wav;base64,${base64Encode(buffer.buffer.asUint8List())}';
  }
}