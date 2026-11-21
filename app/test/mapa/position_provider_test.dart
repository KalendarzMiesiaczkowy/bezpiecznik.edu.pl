import 'dart:async';

import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _Gateway implements LocationGateway {
  _Gateway(this.access, this.stream);

  final LocationAccess access;
  final Stream<Position> stream;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Future<Position?> lastKnown() async => null;

  @override
  Stream<Position> positions() => stream;

  @override
  Future<bool> openSettings() async => true;
}

Position _pos(double lat) => Position(
  latitude: lat,
  longitude: 14.5,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 90,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  test('denied access yields a single null and never reads the stream', () async {
    final c = ProviderContainer(
      overrides: [
        locationGatewayProvider.overrideWithValue(
          _Gateway(LocationAccess.denied, Stream.error(StateError('must not listen'))),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(positionProvider, (_, _) {});
    expect(await c.read(positionProvider.future), isNull);
  });

  test('granted access emits null (no last fix) then each fix; errors become null', () async {
    final controller = StreamController<Position>();
    final c = ProviderContainer(
      overrides: [
        locationGatewayProvider.overrideWithValue(_Gateway(LocationAccess.granted, controller.stream)),
      ],
    );
    addTearDown(c.dispose);
    final seen = <Position?>[];
    c.listen(positionProvider, (_, next) => seen.add(next.value), fireImmediately: false);
    await c.read(positionProvider.future);
    controller.add(_pos(53.4));
    await Future<void>.delayed(Duration.zero);
    controller.addError(StateError('gps off'));
    await Future<void>.delayed(Duration.zero);
    await controller.close();
    expect(seen.map((p) => p?.latitude).toList(), contains(53.4));
    expect(seen.last, isNull);
  });

  test('location settings force the Android LocationManager (no Play services dialog)', () {
    final settings = bezpiecznikLocationSettings();
    expect(settings.forceLocationManager, isTrue);
    expect(settings.toJson()['forceLocationManager'], isTrue);
  });
}
