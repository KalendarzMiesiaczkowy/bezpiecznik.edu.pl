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

/// Single source of position settings. `forceLocationManager` makes the plugin
/// use the Android LocationManager (GPS works offline) instead of the
/// FusedLocationProvider, which would show the Play services "Location
/// Accuracy" resolution dialog over the app (geolocator_android
/// GeolocationManager.createLocationClient / FusedLocationClient).
AndroidSettings bezpiecznikLocationSettings() => AndroidSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 2,
  forceLocationManager: true,
  intervalDuration: const Duration(seconds: 2),
);

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
  Future<Position?> lastKnown() => Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);

  @override
  Stream<Position> positions() => Geolocator.getPositionStream(
    locationSettings: bezpiecznikLocationSettings(),
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

/// Provenance of [positionProvider] emissions, written by it (the map screen
/// reads it to tell a live fix from a last-known one). Untouched defaults mean
/// "an emitted position is live", which keeps provider overrides in tests valid.
class GpsFix {
  const GpsFix({this.lastKnown, this.lastKnownOnly = false, this.lost = false});

  /// Most recent position seen (live or last known), kept after the signal is lost.
  final Position? lastKnown;

  /// The emitted position is only the OS last-known one, not a live fix.
  final bool lastKnownOnly;

  /// The stream failed or services went off after start.
  final bool lost;
}

class GpsFixNotifier extends Notifier<GpsFix> {
  @override
  GpsFix build() => const GpsFix();

  void set(GpsFix fix) => state = fix;
}

final gpsFixProvider = NotifierProvider<GpsFixNotifier, GpsFix>(GpsFixNotifier.new);

/// Device position. Emits `null` while there is no fix (or no access), then
/// every fix. Reused by B04 (shelters) and B05 (compass).
final positionProvider = StreamProvider<Position?>((ref) async* {
  final gateway = ref.watch(locationGatewayProvider);
  final access = await ref.watch(locationAccessProvider.future);
  if (access != LocationAccess.granted) {
    yield null;
    return;
  }
  final fixes = ref.read(gpsFixProvider.notifier);
  final last = await gateway.lastKnown();
  if (last != null) fixes.set(GpsFix(lastKnown: last, lastKnownOnly: true));
  yield last;
  var seen = last;
  try {
    await for (final position in gateway.positions()) {
      seen = position;
      fixes.set(GpsFix(lastKnown: position));
      yield position;
    }
  } on Object {
    // Services switched off or permission revoked while running.
    fixes.set(GpsFix(lastKnown: seen, lost: true));
    yield null;
  }
});
