import 'cpr_config.dart';

enum CprPhase {
  idle,

  /// Initial rescue breaths (child / infant) before the first compressions.
  initialBreaths,
  compressing,

  /// The 2 breaths of the cycle.
  breathing,
  paused,
  stopped,
}

enum CprEventType {
  /// One compression click ([CprEvent.beatInCycle] is 1-based).
  beat,

  /// A breath phase begins ([CprEvent.initial] for the initial breaths).
  breathsStart,

  /// Compressions (re)start after start, breaths or pause.
  compressionsStart,

  /// Time to swap the person doing compressions.
  rescuerChange,
}

class CprEvent {
  const CprEvent(this.type, {this.beatInCycle = 0, this.initial = false});

  final CprEventType type;
  final int beatInCycle;
  final bool initial;

  @override
  String toString() => 'CprEvent($type, $beatInCycle${initial ? ', initial' : ''})';
}

/// Immutable view of the engine for the UI.
class CprSnapshot {
  const CprSnapshot({
    required this.phase,
    required this.beatInCycle,
    required this.cycleLength,
    required this.totalCompressions,
    required this.completedCycles,
    required this.elapsed,
    required this.untilChange,
    required this.breathRemaining,
    required this.awaitingTap,
    required this.changesDue,
    required this.sinceChange,
  });

  final CprPhase phase;

  /// Compressions done in the current cycle (0..cycleLength).
  final int beatInCycle;
  final int cycleLength;
  final int totalCompressions;
  final int completedCycles;
  final Duration elapsed;
  final Duration untilChange;

  /// Time left in a timed breath phase; null when untimed or not breathing.
  final Duration? breathRemaining;

  /// True when the breath phase ends only on the rescuer's tap.
  final bool awaitingTap;

  /// How many rescuer-change prompts have fired so far.
  final int changesDue;

  /// Time since the latest change prompt (zero when none fired).
  final Duration sinceChange;

  bool get active => phase != CprPhase.idle && phase != CprPhase.stopped;
}

/// Pure timing engine of the CPR instructor. It never reads a real clock:
/// the caller supplies a monotonic [clock] and calls [tick]; every due event
/// is returned in order. Beats are scheduled from the start of the current
/// compression run (`runStart + n * interval`), so there is no drift.
///
/// The stopwatch and the rescuer-change timer run on wall time (also during
/// a pause): they describe the whole resuscitation, not the pressing time.
class CprEngine {
  CprEngine({required this.config, required this.variant, required this.clock});

  final CprConfig config;
  final CprVariantConfig variant;
  final Duration Function() clock;

  CprPhase _phase = CprPhase.idle;
  CprPhase _pausedFrom = CprPhase.idle;
  late Duration _startedAt;
  Duration? _stoppedAt;
  late Duration _runStart;
  int _inCycle = 0;
  int _total = 0;
  int _cycles = 0;
  int _changes = 0;
  Duration? _breathEnd;
  Duration? _breathLeftWhenPaused;

  Duration get _interval => config.beatInterval;

  CprPhase get phase => _phase;

  /// Starts the instructor. Returns the first events.
  List<CprEvent> start() {
    if (_phase != CprPhase.idle) return const [];
    final now = clock();
    _startedAt = now;
    if (variant.initialBreaths > 0) {
      _enterBreathing(now, initial: true);
      return [const CprEvent(CprEventType.breathsStart, initial: true)];
    }
    _beginCompressions(now);
    return [const CprEvent(CprEventType.compressionsStart), ...tick()];
  }

  void _beginCompressions(Duration now) {
    _phase = CprPhase.compressing;
    _runStart = now - _interval * _inCycle;
  }

  void _enterBreathing(Duration now, {required bool initial}) {
    _phase = initial ? CprPhase.initialBreaths : CprPhase.breathing;
    final len = variant.breathPhase;
    _breathEnd = len == null ? null : now + len;
  }

  /// Ends the breath phase (tap, or timeout from [tick]).
  List<CprEvent> finishBreaths() {
    if (_phase != CprPhase.breathing && _phase != CprPhase.initialBreaths) return const [];
    final now = clock();
    _inCycle = 0;
    _breathEnd = null;
    _beginCompressions(now);
    return [const CprEvent(CprEventType.compressionsStart), ...tick()];
  }

  void pause() {
    if (_phase != CprPhase.compressing && _phase != CprPhase.breathing && _phase != CprPhase.initialBreaths) {
      return;
    }
    final now = clock();
    _pausedFrom = _phase;
    _breathLeftWhenPaused = _breathEnd == null ? null : _breathEnd! - now;
    _phase = CprPhase.paused;
  }

  List<CprEvent> resume() {
    if (_phase != CprPhase.paused) return const [];
    final now = clock();
    if (_pausedFrom == CprPhase.compressing) {
      _beginCompressions(now);
      return [const CprEvent(CprEventType.compressionsStart), ...tick()];
    }
    _phase = _pausedFrom;
    final left = _breathLeftWhenPaused;
    _breathEnd = left == null ? null : now + left;
    return const [];
  }

  void stop() {
    if (_phase == CprPhase.idle || _phase == CprPhase.stopped) return;
    _stoppedAt = clock();
    _phase = CprPhase.stopped;
  }

  Duration _nextChangeAt() => _startedAt + config.rescuerChange * (_changes + 1);

  /// Processes everything due up to now.
  List<CprEvent> tick() {
    final events = <CprEvent>[];
    if (_phase == CprPhase.idle || _phase == CprPhase.stopped) return events;
    final now = clock();
    for (var guard = 0; guard < 100000; guard++) {
      final change = _nextChangeAt();
      Duration? other;
      if (_phase == CprPhase.compressing) {
        // Beat n+1 is due at runStart + n * interval; after the last beat of
        // the cycle the breath phase starts one interval later.
        other = _runStart + _interval * _inCycle;
        if (_inCycle >= variant.compressions) other = _runStart + _interval * variant.compressions;
      } else if (_breathEnd != null && (_phase == CprPhase.breathing || _phase == CprPhase.initialBreaths)) {
        other = _breathEnd;
      }
      final changeDue = change <= now;
      final otherDue = other != null && other <= now;
      if (!changeDue && !otherDue) break;
      if (changeDue && (!otherDue || change <= other)) {
        _changes++;
        events.add(const CprEvent(CprEventType.rescuerChange));
        continue;
      }
      if (_phase == CprPhase.compressing) {
        if (_inCycle >= variant.compressions) {
          _cycles++;
          _enterBreathing(other!, initial: false);
          events.add(const CprEvent(CprEventType.breathsStart));
        } else {
          _inCycle++;
          _total++;
          events.add(CprEvent(CprEventType.beat, beatInCycle: _inCycle));
        }
      } else {
        // Timed breath phase ended.
        final end = other!;
        _inCycle = 0;
        _breathEnd = null;
        _runStart = end;
        _phase = CprPhase.compressing;
        events.add(const CprEvent(CprEventType.compressionsStart));
      }
    }
    return events;
  }

  CprSnapshot get snapshot {
    final now = _stoppedAt ?? (_phase == CprPhase.idle ? Duration.zero : clock());
    final idle = _phase == CprPhase.idle;
    Duration? breathLeft;
    var awaiting = false;
    final p = _phase == CprPhase.paused ? _pausedFrom : _phase;
    if (p == CprPhase.breathing || p == CprPhase.initialBreaths) {
      if (_phase == CprPhase.paused) {
        breathLeft = _breathLeftWhenPaused;
      } else if (_breathEnd != null) {
        final left = _breathEnd! - now;
        breathLeft = left.isNegative ? Duration.zero : left;
      }
      awaiting = breathLeft == null;
    }
    var untilChange = idle ? config.rescuerChange : _nextChangeAt() - now;
    if (untilChange.isNegative) untilChange = Duration.zero;
    return CprSnapshot(
      phase: _phase,
      beatInCycle: _inCycle,
      cycleLength: variant.compressions,
      totalCompressions: _total,
      completedCycles: _cycles,
      elapsed: idle ? Duration.zero : now - _startedAt,
      untilChange: untilChange,
      breathRemaining: breathLeft,
      awaitingTap: awaiting,
      changesDue: _changes,
      sinceChange: idle || _changes == 0 ? Duration.zero : now - (_startedAt + config.rescuerChange * _changes),
    );
  }
}
