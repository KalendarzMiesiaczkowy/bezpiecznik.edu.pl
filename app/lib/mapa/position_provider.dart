import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Whether the app may read the device location.
enum LocationAccess {
  granted,

  /// Permission denied (can be asked again) or denied forever.
  denied,

  /// Location services (GPS switch) are off.
  serviceOff,
}

/// Thin seam over `Geolocator` so tests and B04/B05 can fake it.
abstract class LocationGateway {
  /// Checks and, when needed, requests the runtime permission.
  Future<LocationAccess> ensureAccess();

  Future<Position?> lastKnown();

  Stream<Position> positions();

  Future<bool> openSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse
        ? LocationAccess.granted
        : LocationAccess.denied;
  }

  @override
  Future<Position?> lastKnown() => Geolocator.getLastKnownPosition();

  @override
  Stream<Position> positions() => Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
      intervalDuration: const Duration(seconds: 2),
    ),
  );

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();
}

final locationGatewayProvider = Provider<LocationGateway>((ref) => const GeolocatorGateway());

/// Permission/service state; requests the permission the first time it is read
/// (E0 onboarding will later ask earlier, then this resolves immediately).
final locationAccessProvider = FutureProvider<LocationAccess>(
  (ref) => ref.watch(locationGatewayProvider).ensureAccess(),
);

/// Device position. Emits `null` while there is no fix (or no access), then
/// every fix. Reused by B04 (shelters) and B05 (compass).
final positionProvider = StreamProvider<Position?>((ref) async* {
  final gateway = ref.watch(locationGatewayProvider);
  final access = await ref.watch(locationAccessProvider.future);
  if (access != LocationAccess.granted) {
    yield null;
    return;
  }
  yield await gateway.lastKnown();
  try {
    await for (final position in gateway.positions()) {
      yield position;
    }
  } on Object {
    // Services switched off or permission revoked while running.
    yield null;
  }
});
