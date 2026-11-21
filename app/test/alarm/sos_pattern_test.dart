import 'package:flutter_test/flutter_test.dart';
import 'package:bezpiecznik/alarm/signal/sos_pattern.dart';

void main() {
  test('pattern is ··· ––– ··· with spec units', () {
    final p = sosPattern(unitMs: 1);
    expect(p.where((s) => s.on).map((s) => s.ms), [1, 1, 1, 3, 3, 3, 1, 1, 1]);
    expect(p.where((s) => !s.on).map((s) => s.ms), [1, 1, 3, 1, 1, 3, 1, 1, 7]);
    expect(sosPattern().first.ms, 200);
  });

  test('runner toggles torch on the pattern timeline, honours pause, ends off', () async {
    final log = <String>[];
    late SosRunner r;
    var elapsed = 0;
    var cycles = 0;
    r = SosRunner(
      pauseMs: 10000,
      setTorch: (on) async => log.add('${on ? 1 : 0}@$elapsed'),
      wait: (d) async {
        elapsed += d.inMilliseconds;
        if (d.inMilliseconds == 10000 && ++cycles == 2) r.stop();
      },
    );
    await r.run();
    // first dot on at 0, off at 200, next on at 400
    expect(log.take(3), ['1@0', '0@200', '1@400']);
    final total = sosPattern().fold<int>(0, (a, s) => a + s.ms);
    expect(total, 34 * 200);
    expect(elapsed, 2 * (total + 10000));
    expect(log.last.startsWith('0@'), isTrue);
    expect(r.running, isFalse);
  });
}
