import 'dart:math' as math;

import 'package:bezpiecznik/mapa/punkty/geo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Independent distance: spherical law of cosines.
double _cosines(double a, double b, double c, double d) {
  double r(double x) => x * math.pi / 180;
  return earthRadiusM *
      math.acos(math.sin(r(a)) * math.sin(r(c)) +
          math.cos(r(a)) * math.cos(r(c)) * math.cos(r(d - b)));
}

void main() {
  test('Szczecin to Warszawa is about 454 km, matches law of cosines', () {
    final d = haversineM(53.4285, 14.5528, 52.2297, 21.0122);
    expect(d, closeTo(_cosines(53.4285, 14.5528, 52.2297, 21.0122), 50));
    expect(d / 1000, inInclusiveRange(450, 458));
  });

  test('one degree of latitude is 111.2 km, zero distance is zero', () {
    expect(haversineM(0, 0, 1, 0), closeTo(111195, 100));
    expect(haversineM(53.4, 14.5, 53.4, 14.5), 0);
  });

  test('cardinal bearings on the equator and meridian', () {
    expect(bearingDeg(0, 0, 1, 0), closeTo(0, 1e-6));
    expect(bearingDeg(0, 0, 0, 1), closeTo(90, 1e-6));
    expect(bearingDeg(1, 0, 0, 0), closeTo(180, 1e-6));
    expect(bearingDeg(0, 1, 0, 0), closeTo(270, 1e-6));
  });

  test('Szczecin to Warszawa bearing is east-south-east (about 110 deg)', () {
    final b = bearingDeg(53.4285, 14.5528, 52.2297, 21.0122);
    // Independent: bearing from 3D unit vectors (tangent direction toward B).
    double r(double x) => x * math.pi / 180;
    final a = [53.4285, 14.5528], c = [52.2297, 21.0122];
    List<double> v(List<double> p) =>
        [math.cos(r(p[0])) * math.cos(r(p[1])), math.cos(r(p[0])) * math.sin(r(p[1])), math.sin(r(p[0]))];
    final va = v(a), vc = v(c);
    final east = [-math.sin(r(a[1])), math.cos(r(a[1])), 0.0];
    final north = [
      -math.sin(r(a[0])) * math.cos(r(a[1])),
      -math.sin(r(a[0])) * math.sin(r(a[1])),
      math.cos(r(a[0])),
    ];
    double dot(List<double> x, List<double> y) => x[0] * y[0] + x[1] * y[1] + x[2] * y[2];
    final expected = math.atan2(dot(vc, east), dot(vc, north)) * 180 / math.pi;
    expect(va.length, 3);
    expect(b, closeTo(expected, 1e-6));
    expect(b, inInclusiveRange(104, 105));
  });

  test('cardinal names and arrows', () {
    expect(cardinalName(0), 'północ');
    expect(cardinalName(44), 'północny wschód');
    expect(cardinalName(359), 'północ');
    expect(cardinalName(225), 'południowy zachód');
    expect(arrowFor(90), '→');
    expect(arrowFor(200), '↓');
  });

  test('formatDistance', () {
    expect(formatDistance(450.4), '450 m');
    expect(formatDistance(1234), '1,2 km');
  });
}
