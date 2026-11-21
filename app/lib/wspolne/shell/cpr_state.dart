import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of the single, app-wide CPR instructor (the real logic comes in D04).
class CprState {
  const CprState({this.running = false, this.elapsed = Duration.zero});

  final bool running;
  final Duration elapsed;
}

/// Minimal notifier: `start()` / `stop()` and an optional one-second elapsed
/// ticker. The CPR session drives the elapsed time itself via [setElapsed] and
/// starts with `selfTick: false`, so only one timer runs per session.
class CprNotifier extends Notifier<CprState> {
  Timer? _timer;

  @override
  CprState build() {
    ref.onDispose(() => _timer?.cancel());
    return const CprState();
  }

  void start({bool selfTick = true}) {
    _timer?.cancel();
    _timer = null;
    state = const CprState(running: true);
    if (!selfTick) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = CprState(running: true, elapsed: state.elapsed + const Duration(seconds: 1));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = const CprState();
  }

  void setElapsed(Duration elapsed) {
    if (state.running) state = CprState(running: true, elapsed: elapsed);
  }
}

final cprProvider = NotifierProvider<CprNotifier, CprState>(CprNotifier.new);

/// True while the CPR instructor runs (drives the `CprIndicator`).
final cprActiveProvider = Provider<bool>(
  (ref) => ref.watch(cprProvider.select((s) => s.running)),
);

/// `mm:ss`, e.g. `03:42`.
String formatCprElapsed(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
