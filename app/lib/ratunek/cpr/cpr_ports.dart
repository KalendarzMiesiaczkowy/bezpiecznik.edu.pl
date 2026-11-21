import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Spoken commands (Polish text comes from the card).
abstract interface class CprVoice {
  Future<void> speak(String text);
  Future<void> stop();
}

/// Metronome click and breath cue.
abstract interface class CprSound {
  Future<void> click();
  Future<void> breathCue();
  Future<void> dispose();
}

/// Per-beat vibration.
abstract interface class CprHaptics {
  Future<void> beat();
}

/// Keeps the screen on while the instructor runs.
abstract interface class CprWakelock {
  Future<void> enable();
  Future<void> disable();
}

/// `flutter_tts` voice, Polish. All failures are swallowed: the instructor
/// must keep working (click + on-screen label) without a voice.
class FlutterTtsCprVoice implements CprVoice {
  FlutterTtsCprVoice([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _init;

  Future<void> _ensure() => _init ??= () async {
    try {
      await _tts.setLanguage('pl-PL');
      await _tts.setSpeechRate(0.5);
    } on Object {
      // Ignored: speak() below fails quietly too.
    }
  }();

  @override
  Future<void> speak(String text) async {
    try {
      await _ensure();
      await _tts.speak(text);
    } on Object {
      // No voice available.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Ignored.
    }
  }
}

/// `audioplayers` pools: low latency, overlapping clicks allowed.
class AudioCprSound implements CprSound {
  static const clickAsset = 'audio/cpr_click.wav';
  static const breathAsset = 'audio/cpr_breath.wav';

  AudioPool? _click;
  AudioPool? _breath;

  Future<AudioPool?> _pool(String asset, int players) async {
    try {
      return await AudioPool.createFromAsset(path: asset, maxPlayers: players);
    } on Object {
      return null;
    }
  }

  Future<void>? _warm;

  /// One shared warm-up: concurrent callers await the same future.
  Future<void> warmUp() => _warm ??= _doWarmUp();

  Future<void> _doWarmUp() async {
    _click = await _pool(clickAsset, 4);
    _breath = await _pool(breathAsset, 1);
  }

  @override
  Future<void> click() async {
    try {
      await warmUp();
      await _click?.start();
    } on Object {
      // Silent metronome is better than a crash.
    }
  }

  @override
  Future<void> breathCue() async {
    try {
      await warmUp();
      await _breath?.start();
    } on Object {
      // Ignored.
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _click?.dispose();
      await _breath?.dispose();
    } on Object {
      // Ignored.
    }
    _click = null;
    _breath = null;
    _warm = null;
  }
}

class VibrationCprHaptics implements CprHaptics {
  @override
  Future<void> beat() async {
    try {
      await Vibration.vibrate(duration: 40);
    } on Object {
      try {
        await HapticFeedback.mediumImpact();
      } on Object {
        // No haptics.
      }
    }
  }
}

class WakelockPlusCprWakelock implements CprWakelock {
  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } on Object {
      // Ignored.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } on Object {
      // Ignored.
    }
  }
}
