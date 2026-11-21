import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ustawienia/settings_store.dart';
import '../../wspolne/shell/cpr_state.dart';
import 'cpr_config.dart';
import 'cpr_engine.dart';
import 'cpr_ports.dart';

/// Bridge to the app-wide overlay state (`CprIndicator`).
abstract interface class CprOverlayPort {
  void start();
  void setElapsed(Duration elapsed);
  void stop();
}

class _NotifierOverlay implements CprOverlayPort {
  _NotifierOverlay(this._ref);
  final Ref _ref;

  @override
  void start() => _ref.read(cprProvider.notifier).start();

  @override
  void setElapsed(Duration elapsed) => _ref.read(cprProvider.notifier).setElapsed(elapsed);

  @override
  void stop() => _ref.read(cprProvider.notifier).stop();
}

/// Owns one running CPR instructor: engine + ticker + click + voice +
/// vibration + wakelock + overlay state. Lives in a provider, so it keeps
/// running when the chat screen is left.
class CprSession extends ChangeNotifier {
  CprSession({
    required this.voice,
    required this.sound,
    required this.haptics,
    required this.wakelock,
    required this.overlay,
    required this.clock,
    this.voiceEnabled = _alwaysTrue,
    this.tickInterval = const Duration(milliseconds: 10),
    this.autoTick = true,
  });

  static bool _alwaysTrue() => true;

  final CprVoice voice;
  final CprSound sound;
  final CprHaptics haptics;
  final CprWakelock wakelock;
  final CprOverlayPort overlay;
  final Duration Function() clock;
  final bool Function() voiceEnabled;
  final Duration tickInterval;

  /// False in tests that drive [tick] by hand.
  final bool autoTick;

  CprEngine? _engine;
  CprConfig? _config;
  Timer? _timer;
  String _shownKey = '';
  int _lastOverlaySecond = -1;

  bool get running => _engine?.snapshot.active ?? false;
  CprSnapshot? get snapshot => _engine?.snapshot;
  CprConfig? get config => _config;
  CprVariantConfig? get variant => _engine?.variant;

  /// Starts the instructor for [variantId]. No-op when already running.
  void start(CprConfig config, String? variantId) {
    if (running) return;
    final v = config.variant(variantId);
    if (v == null) return;
    _config = config;
    final engine = CprEngine(config: config, variant: v, clock: clock);
    _engine = engine;
    _lastOverlaySecond = -1;
    overlay.start();
    unawaited(wakelock.enable());
    final events = engine.start();
    // AED reminder first (card text), then the compress command in one go.
    if (voiceEnabled()) {
      final parts = [
        if (config.voice.aed.isNotEmpty) config.voice.aed,
        if (events.any((e) => e.type == CprEventType.compressionsStart)) config.voice.compress,
      ];
      if (parts.isNotEmpty) unawaited(voice.speak(parts.join('. ')));
    }
    _handle(events, skipStartSpeech: true);
    _syncOverlay();
    if (autoTick) _timer = Timer.periodic(tickInterval, (_) => tick());
    _notifyIfChanged(force: true);
  }

  /// Advances the engine to the clock's now. Called by the ticker.
  void tick() {
    final e = _engine;
    if (e == null) return;
    _handle(e.tick());
    _syncOverlay();
    _notifyIfChanged();
  }

  void pause() {
    _engine?.pause();
    unawaited(voice.stop());
    _syncOverlay();
    _notifyIfChanged(force: true);
  }

  void resume() {
    final e = _engine;
    if (e == null) return;
    _handle(e.resume());
    _notifyIfChanged(force: true);
  }

  /// "Wdechy zrobione": ends the breath phase early / on tap.
  void breathsDone() {
    final e = _engine;
    if (e == null) return;
    _handle(e.finishBreaths());
    _notifyIfChanged(force: true);
  }

  void stop() {
    final e = _engine;
    if (e == null) return;
    e.stop();
    _timer?.cancel();
    _timer = null;
    unawaited(voice.stop());
    unawaited(wakelock.disable());
    overlay.stop();
    _engine = null;
    _shownKey = '';
    notifyListeners();
  }

  void _handle(List<CprEvent> events, {bool skipStartSpeech = false}) {
    final cfg = _config;
    if (cfg == null) return;
    for (final ev in events) {
      switch (ev.type) {
        case CprEventType.beat:
          unawaited(sound.click());
          unawaited(haptics.beat());
        case CprEventType.breathsStart:
          unawaited(sound.breathCue());
          // Only the cycle breaths have a card text ("Dwa oddechy"); the
          // initial breaths of child / infant have none, so they stay silent.
          if (!ev.initial && voiceEnabled()) unawaited(voice.speak(cfg.voice.breaths));
        case CprEventType.compressionsStart:
          if (!skipStartSpeech && voiceEnabled()) unawaited(voice.speak(cfg.voice.compress));
        case CprEventType.rescuerChange:
          // Silent while paused (pause() silenced voice); the engine keeps the
          // change due, so the banner shows after resume.
          if (cfg.voice.change.isNotEmpty && voiceEnabled() && snapshot?.phase != CprPhase.paused) unawaited(voice.speak(cfg.voice.change));
      }
    }
  }

  void _syncOverlay() {
    final s = _engine?.snapshot;
    if (s == null) return;
    final sec = s.elapsed.inSeconds;
    if (sec != _lastOverlaySecond) {
      _lastOverlaySecond = sec;
      overlay.setElapsed(s.elapsed);
    }
  }

  void _notifyIfChanged({bool force = false}) {
    final s = _engine?.snapshot;
    if (s == null) return;
    final key = '${s.phase.index}|${s.beatInCycle}|${s.totalCompressions}|${s.elapsed.inSeconds}|'
        '${s.untilChange.inSeconds}|${s.breathRemaining?.inSeconds}|${s.awaitingTap}';
    if (!force && key == _shownKey) return;
    _shownKey = key;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(wakelock.disable());
    unawaited(voice.stop());
    unawaited(sound.dispose());
    super.dispose();
  }
}

final cprVoiceProvider = Provider<CprVoice>((ref) => FlutterTtsCprVoice());
final cprSoundProvider = Provider<CprSound>((ref) => AudioCprSound());
final cprHapticsProvider = Provider<CprHaptics>((ref) => VibrationCprHaptics());
final cprWakelockProvider = Provider<CprWakelock>((ref) => WakelockPlusCprWakelock());

/// Monotonic clock of the instructor (overridable in tests).
final cprClockProvider = Provider<Duration Function()>((ref) {
  final sw = Stopwatch()..start();
  return () => sw.elapsed;
});

/// The single app-wide instructor session.
final cprSessionProvider = Provider<CprSession>((ref) {
  final session = CprSession(
    voice: ref.watch(cprVoiceProvider),
    sound: ref.watch(cprSoundProvider),
    haptics: ref.watch(cprHapticsProvider),
    wakelock: ref.watch(cprWakelockProvider),
    overlay: _NotifierOverlay(ref),
    clock: ref.watch(cprClockProvider),
    voiceEnabled: () => ref.read(voiceEnabledProvider),
  );
  ref.onDispose(session.dispose);
  return session;
});
