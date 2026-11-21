import 'package:bezpiecznik/mapa/kompas/compass_math.dart';
import 'package:bezpiecznik/mapa/punkty/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relativeAngleDeg wraps to (-180, 180]', () {
    expect(relativeAngleDeg(90, 0), 90);
    expect(relativeAngleDeg(0, 90), -90);
    expect(relativeAngleDeg(10, 350), 20);
    expect(relativeAngleDeg(350, 10), -20);
    expect(relativeAngleDeg(180, 0), 180);
    expect(relativeAngleDeg(45, 45), 0);
  });

  test('headingFromSensors, phone flat', () {
    double h(double mx, double my) => headingFromSensors(0, 0, 9.8, mx, my, -40)!;
    expect(h(0, 30), closeTo(0, 1e-6)); // top faces north
    expect(h(-30, 0), closeTo(90, 1e-6)); // top faces east
    expect(h(0, -30), closeTo(180, 1e-6));
    expect(h(30, 0), closeTo(270, 1e-6));
    expect(headingFromSensors(0, 0, 0, 1, 2, 3), isNull);
  });

  test('field reliability', () {
    expect(fieldIsReliable(0, 30, -40), isTrue); // 50 uT
    expect(fieldIsReliable(0, 5, 0), isFalse);
    expect(fieldIsReliable(100, 0, 0), isFalse);
  });

  test('smoothAngle takes the short way round', () {
    expect(smoothAngle(null, 123), 123);
    expect(smoothAngle(350, 10, alpha: 0.5), closeTo(0, 1e-9));
    expect(smoothAngle(10, 350, alpha: 0.5), closeTo(0, 1e-9));
  });

  test('bearing and distance (B04 helpers) feed the compass', () {
    // Szczecin point due north-east-ish: sanity of the helpers we reuse.
    final b = bearingDeg(53.4285, 14.5528, 53.4385, 14.5528);
    expect(b, closeTo(0, 1e-6));
    expect(haversineM(53.4285, 14.5528, 53.4385, 14.5528), closeTo(1112, 3));
    expect(cardinalName(45), 'północny wschód');
    expect(formatDistance(350), '350 m');
    expect(formatDistance(1234), '1,2 km');
  });

  test('ageText', () {
    expect(ageText(const Duration(seconds: 20)), '20 s');
    expect(ageText(const Duration(minutes: 3, seconds: 5)), '3 min');
    expect(ageText(const Duration(hours: 2)), '2 h');
  });
}
