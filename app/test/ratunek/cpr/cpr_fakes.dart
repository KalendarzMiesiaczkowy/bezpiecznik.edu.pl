import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/ratunek/cpr/cpr_config.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_ports.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_session.dart';

/// `cpr` panel of the shipped RKO card.
Map<String, Object?> rkoCprPanelJson() {
  final card = jsonDecode(File('assets/cards/rko.json').readAsStringSync()) as Map<String, Object?>;
  final panels = card['panels']! as List;
  return Map<String, Object?>.from(panels.firstWhere((p) => (p as Map)['type'] == 'cpr') as Map);
}

CprConfig rkoConfig() => CprConfig.tryParse(rkoCprPanelJson())!;

class FakeClock {
  Duration now = Duration.zero;
  Duration call() => now;
  void advance(Duration d) => now += d;
}

class FakeVoice implements CprVoice {
  final spoken = <String>[];
  int stops = 0;
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async => stops++;
}

class FakeSound implements CprSound {
  int clicks = 0;
  int cues = 0;
  @override
  Future<void> click() async => clicks++;
  @override
  Future<void> breathCue() async => cues++;
  @override
  Future<void> dispose() async {}
}

class FakeHaptics implements CprHaptics {
  int beats = 0;
  @override
  Future<void> beat() async => beats++;
}

class FakeWakelock implements CprWakelock {
  bool on = false;
  int enables = 0;
  @override
  Future<void> enable() async {
    on = true;
    enables++;
  }

  @override
  Future<void> disable() async => on = false;
}

class FakeOverlay implements CprOverlayPort {
  bool running = false;
  final elapsed = <Duration>[];
  @override
  void start() => running = true;
  @override
  void setElapsed(Duration e) => elapsed.add(e);
  @override
  void stop() => running = false;
}

class Rig {
  Rig() {
    session = CprSession(
      voice: voice,
      sound: sound,
      haptics: haptics,
      wakelock: wakelock,
      overlay: overlay,
      clock: clock.call,
      voiceEnabled: () => voiceOn,
      autoTick: false,
    );
  }
  final clock = FakeClock();
  final voice = FakeVoice();
  final sound = FakeSound();
  final haptics = FakeHaptics();
  final wakelock = FakeWakelock();
  final overlay = FakeOverlay();
  bool voiceOn = true;
  late final CprSession session;

  void advance(Duration d) {
    clock.advance(d);
    session.tick();
  }
}
