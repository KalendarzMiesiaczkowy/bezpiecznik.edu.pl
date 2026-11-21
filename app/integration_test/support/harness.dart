import 'dart:async';

import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory profile store with onboarding already completed, so E2E tests
/// that are not about onboarding start on the chat screen (no async redirect).
Future<ProfileStore> onboardedProfileStore() async {
  final store = ProfileStore.inMemory();
  await store.setOnboardingDone(true);
  return store;
}

/// Pumps frames until [finder] matches or [timeout] passes. Use instead of
/// `pumpAndSettle` while spinners or the thinking animation run.
Future<bool> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return true;
  }
  return finder.evaluate().isNotEmpty;
}

/// Deterministic location: permission granted, one fixed fix in Szczecin, no
/// runtime permission dialog (an unanswered native dialog keeps
/// `locationAccessProvider` pending forever under `flutter test`).
class FakeLocationGateway implements LocationGateway {
  const FakeLocationGateway();

  static final Position szczecin = Position(
    latitude: 53.4285,
    longitude: 14.5528,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;

  @override
  Future<Position?> lastKnown() async => szczecin;

  /// Emits the fixed fix once and stays open (like a live stream with no
  /// movement), so no provider sees a completed stream.
  @override
  Stream<Position> positions() async* {
    yield szczecin;
    await Completer<void>().future;
  }

  @override
  Future<bool> openSettings() async => true;
}

/// Provider override for [FakeLocationGateway].
final fakeLocationOverride = locationGatewayProvider.overrideWithValue(const FakeLocationGateway());
