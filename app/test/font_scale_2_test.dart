import 'package:bezpiecznik/czat/ui/quick_actions.dart';
import 'package:bezpiecznik/mapa/kompas/compass_screen.dart';
import 'package:bezpiecznik/mapa/kompas/heading_provider.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bezpiecznik/mapa/punkty/point_sheet.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:bezpiecznik/onboarding/onboarding_screen.dart';
import 'package:bezpiecznik/profil/profile_form.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// BG107: layouts must survive Android font scale 2.0 on 412x915.
Widget app(Widget child) => ProviderScope(
  overrides: [profileStoreProvider.overrideWithValue(ProfileStore.inMemory())],
  child: MaterialApp(
    theme: buildBzTheme(),
    builder: (c, w) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2.0)),
      child: w!,
    ),
    home: child,
  ),
);

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(412, 915);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

/// Hit-testable: the centre of the widget is inside the screen and the widget
/// is the top hit target there.
void reachable(WidgetTester t, Finder f) {
  final c = t.getCenter(f);
  expect(c.dy, lessThan(915));
  expect(
    t.hitTestOnBinding(c).path.any((e) => e.target == t.renderObject(f)),
    isTrue,
  );
}

void main() {
  testWidgets('point sheet: no overflow, Prowadź/Kompas reachable', (t) async {
    phone(t);
    const p = ShelterPoint(
      id: 1,
      kind: 'emergency_shelter',
      lat: 53.43,
      lon: 14.55,
      source: 'OpenStreetMap',
      verifiedAt: '2025-01-01',
      confirmed: false,
      name: 'Schron przy ul. Bardzo Długiej Nazwy 12',
      address: 'ul. Polna 2, Szczecin',
    );
    await t.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: c,
                isScrollControlled: true,
                builder: (_) =>
                    const PointSheet(point: p, fromLat: 53.40, fromLon: 14.50),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Kompas'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    reachable(t, find.text('Prowadź'));
    reachable(t, find.text('Kompas'));
  });

  testWidgets('onboarding step 1: no overflow, Dalej reachable', (t) async {
    phone(t);
    await t.pumpWidget(app(const OnboardingScreen()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    reachable(t, find.byKey(const Key('onb-next')));
  });

  testWidgets('quick actions: Ewakuacja is not split', (t) async {
    phone(t);
    await t.pumpWidget(app(Scaffold(body: QuickActions(onSend: (_) {}))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final h = t.getSize(find.text('Ewakuacja')).height;
    expect(h, lessThan(2 * 22 * 2.0)); // single line
  });

  testWidgets('profile: Nastolatek label wraps without clipping', (t) async {
    phone(t);
    await t.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: ProfileForm(
              initial: HouseholdProfile.empty,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Nastolatek (13–17)'), findsOneWidget);
  });

  testWidgets('onboarding: every step scrolls, primary button reachable', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(app(const OnboardingScreen()));
    await t.pumpAndSettle();
    Future<void> step(String tapKey, String nextPrimary) async {
      reachable(t, find.byKey(Key(tapKey)));
      await t.tap(find.byKey(Key(tapKey)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      reachable(t, find.byKey(Key(nextPrimary)));
    }

    await step('onb-next', 'onb-allow');
    reachable(t, find.byKey(const Key('onb-later')));
    await step('onb-later', 'onb-profile-fill'); // location-denied variant
    reachable(t, find.byKey(const Key('onb-profile-later')));
    await step('onb-profile-fill', 'onb-profile-save');
    reachable(t, find.byKey(const Key('onb-profile-skip')));
    await step('onb-profile-skip', 'onb-start');
  });

  testWidgets('compass: full "Pokaż mapę" label, no exception', (t) async {
    phone(t);
    final pos = Position(
      latitude: 53.4285,
      longitude: 14.5528,
      timestamp: DateTime(2026, 11, 21),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          positionProvider.overrideWith((ref) => Stream.value(pos)),
          headingProvider.overrideWith(
            (ref) => Stream.value(const HeadingReading(90, reliable: true)),
          ),
        ],
        child: app(
          CompassScreen(
            target: const ShelterPoint(
              id: 1,
              kind: 'shelter',
              lat: 53.4385,
              lon: 14.5528,
              address: 'ul. Lipowa 5',
              source: 'KG PSP',
              verifiedAt: '2026-10-12',
              confirmed: true,
            ),
            onShowMap: () {},
            onEnd: () {},
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Pokaż mapę'), findsOneWidget);
    reachable(t, find.text('Pokaż mapę'));
    reachable(t, find.text('Zakończ'));
  });
}
