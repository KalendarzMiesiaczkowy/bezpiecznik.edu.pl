import 'package:bezpiecznik/ratunek/cpr/cpr_config.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cpr_fakes.dart';

CprEngine engineFor(String variant, FakeClock clock, {CprConfig? config}) {
  final cfg = config ?? rkoConfig();
  return CprEngine(config: cfg, variant: cfg.variant(variant)!, clock: clock.call);
}

List<CprEvent> step(CprEngine e, FakeClock c, Duration d) {
  c.advance(d);
  return e.tick();
}

int count(Iterable<CprEvent> evs, CprEventType t) => evs.where((e) => e.type == t).length;

void main() {
  test('config parses the shipped card', () {
    final c = rkoConfig();
    expect(c.rateBpm, 110);
    expect(c.rescuerChange, const Duration(seconds: 120));
    expect(c.beatInterval.inMilliseconds, 545);
    expect(c.variants.map((v) => v.id), ['adult', 'child', 'infant']);
    expect(c.variant('adult')!.breathPhase, const Duration(seconds: 10));
    expect(c.variant('child')!.breathPhase, isNull);
    expect(c.variant('child')!.initialBreaths, 5);
    expect(c.variant('nope')!.id, 'adult');
    expect(c.voice.compress, 'Uciskaj');
  });

  test('config rejects out-of-range or missing values', () {
    final raw = rkoCprPanelJson();
    expect(CprConfig.tryParse({...raw, 'rate_bpm': 90}), isNull);
    expect(CprConfig.tryParse({...raw, 'rate_bpm': 130}), isNull);
    expect(CprConfig.tryParse({...raw, 'rate_bpm': null}), isNull);
    expect(CprConfig.tryParse({...raw, 'rescuer_change_s': null}), isNull);
    expect(CprConfig.tryParse({...raw, 'variants': <Object>[]}), isNull);
    expect(CprConfig.tryParse({...raw, 'voice': null}), isNull);
    expect(CprConfig.tryParse(const {}), isNull);
  });

  test('adult start: compression command and first beat at once', () {
    final c = FakeClock();
    final e = engineFor('adult', c);
    final evs = e.start();
    expect(evs.map((x) => x.type), [CprEventType.compressionsStart, CprEventType.beat]);
    expect(e.snapshot.beatInCycle, 1);
    expect(e.snapshot.phase, CprPhase.compressing);
  });

  test('beats are ~545.45 ms apart at 110 bpm', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    expect(count(step(e, c, const Duration(milliseconds: 545)), CprEventType.beat), 0);
    expect(count(step(e, c, const Duration(milliseconds: 1)), CprEventType.beat), 1);
    expect(count(step(e, c, const Duration(milliseconds: 545)), CprEventType.beat), 1);
    expect(e.snapshot.totalCompressions, 3);
  });

  test('30th beat then breath phase one interval later; timed phase resumes', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    final interval = rkoConfig().beatInterval;
    final evs = step(e, c, interval * 29);
    expect(count(evs, CprEventType.beat), 29); // beats 2..30
    expect(evs.last.beatInCycle, 30);
    expect(e.snapshot.phase, CprPhase.compressing);
    final br = step(e, c, interval);
    expect(br.map((x) => x.type), [CprEventType.breathsStart]);
    expect(e.snapshot.phase, CprPhase.breathing);
    expect(e.snapshot.breathRemaining, const Duration(seconds: 10));
    expect(e.snapshot.completedCycles, 1);
    expect(step(e, c, const Duration(seconds: 9)), isEmpty);
    final resume = step(e, c, const Duration(seconds: 1));
    expect(resume.map((x) => x.type), [CprEventType.compressionsStart, CprEventType.beat]);
    expect(e.snapshot.beatInCycle, 1);
  });

  test('no drift over 2 minutes: every beat within 1 ms of the schedule', () {
    final c = FakeClock();
    final e = engineFor('adult', c);
    final interval = rkoConfig().beatInterval;
    final cycle = interval * 30 + const Duration(seconds: 10);
    final seen = <(Duration, CprEvent)>[];
    for (final ev in e.start()) {
      seen.add((c.now, ev));
    }
    while (c.now < const Duration(seconds: 120)) {
      c.advance(const Duration(milliseconds: 1));
      for (final ev in e.tick()) {
        seen.add((c.now, ev));
      }
    }
    final beats = seen.where((s) => s.$2.type == CprEventType.beat).toList();
    expect(beats.length, greaterThan(100));
    for (final (at, ev) in beats) {
      // Count full cycles by total beats seen before this one.
      final idx = beats.indexWhere((b) => identical(b.$2, ev));
      final k = idx ~/ 30;
      final expected = cycle * k + interval * (ev.beatInCycle - 1);
      expect((at - expected).inMicroseconds, inInclusiveRange(0, 1000), reason: 'beat #$idx');
    }
  });

  test('rescuer change prompt at 120 s and every 120 s after', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    var changes = <Duration>[];
    while (c.now < const Duration(seconds: 250)) {
      c.advance(const Duration(milliseconds: 100));
      for (final ev in e.tick()) {
        if (ev.type == CprEventType.rescuerChange) changes.add(c.now);
      }
    }
    expect(changes, [const Duration(seconds: 120), const Duration(seconds: 240)]);
    changes = [];
  });

  test('stopwatch and change countdown', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    step(e, c, const Duration(seconds: 102));
    expect(e.snapshot.elapsed, const Duration(seconds: 102));
    expect(e.snapshot.untilChange, const Duration(seconds: 18));
    step(e, c, const Duration(seconds: 18));
    expect(e.snapshot.changesDue, 1);
    expect(e.snapshot.untilChange, const Duration(seconds: 120));
    expect(e.snapshot.sinceChange, Duration.zero);
    step(e, c, const Duration(seconds: 3));
    expect(e.snapshot.sinceChange, const Duration(seconds: 3));
  });

  test('pause stops beats, stopwatch keeps running, resume beats at once', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    step(e, c, const Duration(seconds: 2));
    final before = e.snapshot.totalCompressions;
    final inCycle = e.snapshot.beatInCycle;
    e.pause();
    expect(e.snapshot.phase, CprPhase.paused);
    expect(step(e, c, const Duration(seconds: 30)), isEmpty);
    expect(e.snapshot.totalCompressions, before);
    expect(e.snapshot.elapsed, const Duration(seconds: 32));
    final evs = e.resume();
    expect(evs.map((x) => x.type), [CprEventType.compressionsStart, CprEventType.beat]);
    expect(e.snapshot.beatInCycle, inCycle + 1);
    expect(e.snapshot.phase, CprPhase.compressing);
  });

  test('pause inside a timed breath phase keeps the remaining time', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    step(e, c, rkoConfig().beatInterval * 30);
    step(e, c, const Duration(seconds: 4));
    e.pause();
    step(e, c, const Duration(seconds: 60));
    expect(e.snapshot.breathRemaining, const Duration(seconds: 6));
    e.resume();
    expect(step(e, c, const Duration(seconds: 5)), isEmpty);
    expect(step(e, c, const Duration(seconds: 1)).first.type, CprEventType.compressionsStart);
  });

  test('child: initial breaths wait for the tap, then compressions', () {
    final c = FakeClock();
    final e = engineFor('child', c);
    final evs = e.start();
    expect(evs.single.type, CprEventType.breathsStart);
    expect(evs.single.initial, isTrue);
    expect(e.snapshot.phase, CprPhase.initialBreaths);
    expect(e.snapshot.awaitingTap, isTrue);
    expect(step(e, c, const Duration(seconds: 90)).where((x) => x.type == CprEventType.beat), isEmpty);
    final go = e.finishBreaths();
    expect(go.map((x) => x.type), [CprEventType.compressionsStart, CprEventType.beat]);
    expect(e.snapshot.awaitingTap, isFalse);
  });

  test('child: after 30 beats the breath phase waits for the tap', () {
    final c = FakeClock();
    final e = engineFor('infant', c)..start();
    e.finishBreaths();
    step(e, c, rkoConfig().beatInterval * 30);
    expect(e.snapshot.phase, CprPhase.breathing);
    expect(e.snapshot.awaitingTap, isTrue);
    expect(step(e, c, const Duration(seconds: 60)).where((x) => x.type == CprEventType.beat), isEmpty);
    expect(e.snapshot.phase, CprPhase.breathing);
    final go = e.finishBreaths();
    expect(go.last.beatInCycle, 1);
    expect(e.snapshot.completedCycles, 1);
  });

  test('stop freezes the stopwatch; ticks do nothing', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    step(e, c, const Duration(seconds: 5));
    e.stop();
    step(e, c, const Duration(seconds: 50));
    expect(e.snapshot.phase, CprPhase.stopped);
    expect(e.snapshot.elapsed, const Duration(seconds: 5));
    expect(e.tick(), isEmpty);
    expect(e.snapshot.active, isFalse);
  });

  test('a long gap between ticks still emits every due beat in order', () {
    final c = FakeClock();
    final e = engineFor('adult', c)..start();
    final evs = step(e, c, const Duration(seconds: 5));
    final nums = evs.where((x) => x.type == CprEventType.beat).map((x) => x.beatInCycle).toList();
    expect(nums, List.generate(nums.length, (i) => i + 2));
  });
}
