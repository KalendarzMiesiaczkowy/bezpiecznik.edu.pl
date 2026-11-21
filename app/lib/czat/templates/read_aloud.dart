import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech port for the `steps` "Czytaj na glos" button. Fakeable in
/// tests through [readAloudVoiceProvider].
abstract interface class ReadAloudVoice {
  /// True when a Polish voice can be used. Never throws.
  Future<bool> isAvailable();

  /// Speaks [text] and completes when it finished or was stopped. Never throws.
  Future<void> speak(String text);

  /// Stops any speech. Never throws.
  Future<void> stop();
}

/// `flutter_tts` implementation, pl-PL. Every failure is swallowed: without a
/// voice the button is simply hidden.
class FlutterTtsReadAloudVoice implements ReadAloudVoice {
  FlutterTtsReadAloudVoice([FlutterTts? tts]) : _tts = tts;

  FlutterTts? _tts;
  Future<bool>? _init;

  FlutterTts get _engine => _tts ??= FlutterTts();

  Future<bool> _ensure() => _init ??= () async {
    try {
      final ok = await _engine.isLanguageAvailable('pl-PL');
      if (ok != true) return false;
      await _engine.setLanguage('pl-PL');
      await _engine.setSpeechRate(0.5);
      await _engine.awaitSpeakCompletion(true);
      return true;
    } on Object {
      return false;
    }
  }();

  @override
  Future<bool> isAvailable() => _ensure();

  @override
  Future<void> speak(String text) async {
    try {
      if (!await _ensure()) return;
      await _engine.speak(text);
    } on Object {
      // No voice available.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } on Object {
      // Ignored.
    }
  }
}

final readAloudVoiceProvider = Provider<ReadAloudVoice>((ref) {
  final voice = FlutterTtsReadAloudVoice();
  ref.onDispose(voice.stop);
  return voice;
});
