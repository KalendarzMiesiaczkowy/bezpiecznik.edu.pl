import 'package:flutter_test/flutter_test.dart';

import 'cpr_fakes.dart';

void main() {
  test('start: overlay, wakelock, AED + compress speech, first click and vibration', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    expect(r.session.running, isTrue);
    expect(r.overlay.running, isTrue);
    expect(r.wakelock.on, isTrue);
    expect(r.voice.spoken, ['Niech ktoś przyniesie AED. Uciskaj']);
    expect(r.sound.clicks, 1);
    expect(r.haptics.beats, 1);
    r.session.stop();
  });

  test('every beat clicks and vibrates', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    r.advance(const Duration(seconds: 5));
    final total = r.session.snapshot!.totalCompressions;
    expect(total, greaterThan(8));
    expect(r.sound.clicks, total);
    expect(r.haptics.beats, total);
    r.session.stop();
  });

  test('breath phase: cue and "Dwa oddechy"; then Uciskaj again', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    r.advance(rkoConfig().beatInterval * 30);
    expect(r.sound.cues, 1);
    expect(r.voice.spoken.last, 'Dwa oddechy');
    r.advance(const Duration(seconds: 10));
    expect(r.voice.spoken.last, 'Uciskaj');
    r.session.stop();
  });

  test('child: initial breaths are silent and wait for the tap', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'child');
    expect(r.voice.spoken, ['Niech ktoś przyniesie AED']);
    expect(r.sound.clicks, 0);
    r.advance(const Duration(seconds: 20));
    expect(r.sound.clicks, 0);
    r.session.breathsDone();
    expect(r.sound.clicks, 1);
    expect(r.voice.spoken.last, 'Uciskaj');
    r.session.stop();
  });

  test('rescuer change is spoken at 120 s', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    for (var i = 0; i < 1200; i++) {
      r.advance(const Duration(milliseconds: 100));
    }
    expect(r.voice.spoken.where((s) => s == 'Zmiana ratownika'), hasLength(1));
    r.session.stop();
  });

  test('voice disabled in settings: no speech, clicks still play', () {
    final r = Rig()..voiceOn = false;
    r.session.start(rkoConfig(), 'adult');
    r.advance(const Duration(seconds: 30));
    expect(r.voice.spoken, isEmpty);
    expect(r.sound.clicks, greaterThan(0));
    r.session.stop();
  });

  test('pause stops clicks and speech; resume continues', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    r.advance(const Duration(seconds: 1));
    r.session.pause();
    final clicks = r.sound.clicks;
    r.advance(const Duration(seconds: 20));
    expect(r.sound.clicks, clicks);
    expect(r.voice.stops, 1);
    r.session.resume();
    expect(r.sound.clicks, clicks + 1);
    r.session.stop();
  });

  test('rescuer change is not spoken while paused; due after resume', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    r.advance(const Duration(seconds: 100));
    r.session.pause();
    r.advance(const Duration(seconds: 40));
    expect(r.voice.spoken.where((s) => s == 'Zmiana ratownika'), isEmpty);
    expect(r.session.snapshot!.changesDue, 1);
    r.session.resume();
    expect(r.voice.spoken.where((s) => s == 'Zmiana ratownika'), isEmpty);
    r.session.stop();
  });

  test('overlay elapsed follows the stopwatch once per second; stop clears everything', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    for (var i = 0; i < 35; i++) {
      r.advance(const Duration(milliseconds: 100));
    }
    expect(r.overlay.elapsed, [Duration.zero, const Duration(seconds: 1), const Duration(seconds: 2), const Duration(seconds: 3)]);
    r.session.stop();
    expect(r.session.running, isFalse);
    expect(r.overlay.running, isFalse);
    expect(r.wakelock.on, isFalse);
  });

  test('second start while running is ignored; restart after stop works', () {
    final r = Rig();
    r.session.start(rkoConfig(), 'adult');
    r.session.start(rkoConfig(), 'child');
    expect(r.session.variant!.id, 'adult');
    expect(r.wakelock.enables, 1);
    r.session.stop();
    r.session.start(rkoConfig(), 'child');
    expect(r.session.variant!.id, 'child');
    r.session.stop();
  });
}
