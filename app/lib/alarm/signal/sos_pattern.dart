/// One step of the flashlight pattern: torch [on] for [ms].
class SosStep {
  const SosStep(this.on, this.ms);
  final bool on;
  final int ms;
}

/// Morse unit from the spec (`sygnal-ratunkowy`, template `signal`).
const sosUnitMs = 200;

/// One full SOS `··· ––– ···`: dot 1 unit, dash 3, gap in letter 1, between
/// letters 3, after the whole SOS 7 units.
List<SosStep> sosPattern({int unitMs = sosUnitMs}) {
  const letters = [
    [1, 1, 1],
    [3, 3, 3],
    [1, 1, 1],
  ];
  final steps = <SosStep>[];
  for (var l = 0; l < letters.length; l++) {
    for (var i = 0; i < letters[l].length; i++) {
      steps.add(SosStep(true, letters[l][i] * unitMs));
      final gap = i < 2 ? 1 : (l < 2 ? 3 : 7);
      steps.add(SosStep(false, gap * unitMs));
    }
  }
  return steps;
}

/// Runs the pattern in a loop until [stop]. [setTorch] drives the lamp,
/// [wait] is injectable so tests use a fake clock. [pauseMs] is the chosen
/// break between repetitions (0 / 10 s / 30 s / 60 s).
class SosRunner {
  SosRunner({required this.setTorch, Future<void> Function(Duration)? wait, this.pauseMs = 0})
      : _wait = wait ?? Future.delayed;

  final Future<void> Function(bool on) setTorch;
  final Future<void> Function(Duration) _wait;
  int pauseMs;
  bool _running = false;

  bool get running => _running;

  Future<void> run() async {
    _running = true;
    try {
      while (_running) {
        for (final s in sosPattern()) {
          if (!_running) break;
          await setTorch(s.on);
          await _wait(Duration(milliseconds: s.ms));
        }
        if (_running && pauseMs > 0) await _wait(Duration(milliseconds: pauseMs));
      }
    } finally {
      _running = false;
      await setTorch(false);
    }
  }

  void stop() => _running = false;
}
