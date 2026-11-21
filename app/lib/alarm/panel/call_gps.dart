import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../mapa/position_provider.dart';

/// GPS state of the contact panel.
class CallGps {
  const CallGps({required this.access, this.position, this.fresh = false});

  final LocationAccess access;
  final Position? position;

  /// True for a live fix, false for the last known position.
  final bool fresh;
}

/// High-accuracy position stream that lives only while the panel watches it
/// (autoDispose), so GPS returns to normal after the panel closes.
final callGpsProvider = StreamProvider.autoDispose<CallGps>((ref) async* {
  final gateway = ref.watch(locationGatewayProvider);
  final access = await ref.watch(locationAccessProvider.future);
  if (access != LocationAccess.granted) {
    yield CallGps(access: access);
    return;
  }
  yield CallGps(access: access, position: await gateway.lastKnown());
  try {
    await for (final p in gateway.positions()) {
      yield CallGps(access: access, position: p, fresh: true);
    }
  } on Object {
    yield const CallGps(access: LocationAccess.serviceOff);
  }
});
