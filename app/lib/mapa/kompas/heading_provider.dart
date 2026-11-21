import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'compass_math.dart';

/// Phone heading (degrees from magnetic north) and whether it can be trusted.
class HeadingReading {
  const HeadingReading(this.degrees, {required this.reliable});
  final double degrees;
  final bool reliable;
}

/// Emits `null` when the phone gives no heading (no magnetometer or no events
/// for [kNoSensorTimeout]), otherwise smoothed readings. Overridable in tests.
final headingProvider = StreamProvider.autoDispose<HeadingReading?>((ref) {
  final out = StreamController<HeadingReading?>();
  AccelerometerEvent? acc;
  double? smoothed;
  void fail(Object _) {
    if (!out.isClosed) out.add(null);
  }

  final subs = <StreamSubscription<Object>>[
    accelerometerEventStream().listen((e) => acc = e, onError: fail),
    magnetometerEventStream().listen((m) {
      final a = acc;
      if (a == null) return;
      final h = headingFromSensors(a.x, a.y, a.z, m.x, m.y, m.z);
      if (h == null) return;
      smoothed = smoothAngle(smoothed, h);
      out.add(HeadingReading(smoothed!, reliable: fieldIsReliable(m.x, m.y, m.z)));
    }, onError: fail),
  ];
  final timer = Timer(kNoSensorTimeout, () {
    if (smoothed == null) fail('timeout');
  });
  ref.onDispose(() {
    timer.cancel();
    for (final s in subs) {
      s.cancel();
    }
    out.close();
  });
  return out.stream;
});

const kNoSensorTimeout = Duration(seconds: 3);
