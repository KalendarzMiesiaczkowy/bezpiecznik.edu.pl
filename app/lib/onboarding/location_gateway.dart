import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Abstraction over the location permission request (faked in tests).
abstract class LocationPermissionGateway {
  /// Requests "while in use" permission; true when granted.
  Future<bool> request();
}

class GeolocatorPermissionGateway implements LocationPermissionGateway {
  const GeolocatorPermissionGateway();

  @override
  Future<bool> request() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p == LocationPermission.whileInUse || p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }
}

final locationPermissionGatewayProvider = Provider<LocationPermissionGateway>(
  (ref) => const GeolocatorPermissionGateway(),
);
