import 'dart:math' as math;

// Distance, bearing, cardinal names and formatDistance live in
// ../punkty/geo.dart (B04); only the heading-related maths is here.

/// Signed angle in degrees in (-180, 180] to rotate an "up" arrow so it points
/// at [bearing] when the phone's top points at [heading] (spec: `bearingToTarget − heading`).
double relativeAngleDeg(double bearing, double heading) {
  final d = ((bearing - heading) % 360 + 360) % 360;
  return d > 180 ? d - 360 : d;
}

/// Tilt-compensated heading (degrees clockwise from magnetic north, [0, 360))
/// of the phone's top edge, from raw accelerometer and magnetometer vectors in
/// the Android device frame. Same maths as `SensorManager.getRotationMatrix`.
/// Valid for a phone held roughly flat (as a compass is used).
/// Returns null when the vectors are degenerate (free fall, no field).
// ponytail: magnetic, not true north (PL declination ~ +5 deg); add a
// declination model if the error matters.
double? headingFromSensors(
  double ax, double ay, double az,
  double mx, double my, double mz,
) {
  // H = M x A (points east), M' = A x H (points to magnetic north in the
  // horizontal plane); azimuth = atan2(H_y, M'_y).
  final hx = my * az - mz * ay;
  final hy = mz * ax - mx * az;
  final hz = mx * ay - my * ax;
  final hn = math.sqrt(hx * hx + hy * hy + hz * hz);
  final an = math.sqrt(ax * ax + ay * ay + az * az);
  if (hn < 0.1 || an < 0.1) return null; // Android uses the same 0.1 cutoff
  final myN = (az / an) * (hx / hn) - (ax / an) * (hz / hn);
  final deg = math.atan2(hy / hn, myN) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Magnetic field strength (µT) outside which the reading is not trusted
/// (Earth's field is ~25-65 µT; Android's own check uses a similar range).
bool fieldIsReliable(double mx, double my, double mz) {
  final b = math.sqrt(mx * mx + my * my + mz * mz);
  return b >= 20 && b <= 70;
}

/// Circular low-pass: moves [previous] towards [next] by [alpha] along the
/// shortest arc. Result in [0, 360).
double smoothAngle(double? previous, double next, {double alpha = 0.25}) {
  if (previous == null) return next;
  final delta = relativeAngleDeg(next, previous);
  return ((previous + alpha * delta) % 360 + 360) % 360;
}

/// "3 min" style age for the last-fix notice.
String ageText(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds < 0 ? 0 : d.inSeconds} s';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h';
}
