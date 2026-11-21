import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/mapa/punkty/point_sheet.dart';
import 'package:bezpiecznik/onboarding/location_gateway.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';

/// Q06a demo recording: the five key paths at a watchable pace (real-time
/// pauses between steps). Production answer path (host LLM over adb reverse),
/// real rescue cards, real MBTiles; only location, launcher and storage are
/// faked. `DEMO_MARK` lines in logcat give the cut points for the video.
/// Run: `flutter test integration_test/demo_test.dart -d emulator-5554 --dart-define=LLM=host`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void mark(String name) => debugPrint('DEMO_MARK $name ${DateTime.now().millisecondsSinceEpoch}');

  /// Real-time pause with frames running (spinners, timers, CPR metronome).
  Future<void> linger(WidgetTester tester, double seconds) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> typeAndSend(WidgetTester tester, String q) async {
    final field = find.byKey(const Key('composer-field'));
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, q);
    await tester.pump();
    await linger(tester, 1.2);
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
  }

  Future<ProfileStore> profileWithIce() async {
    final store = await onboardedProfileStore();
    await store.saveProfile(
      const HouseholdProfile(
        medications: [Medication(name: 'insulina')],
        iceContacts: [IceContact(name: 'Mama', phone: '+48600100200')],
      ),
    );
    return store;
  }

  testWidgets('5 onboarding + profile', (tester) async {
    final store = ProfileStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(store),
          locationPermissionGatewayProvider.overrideWithValue(_GrantedGateway()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('onb-next')));
    mark('onboarding');
    await linger(tester, 3);
    await tester.tap(find.byKey(const Key('onb-next')));
    await linger(tester, 2.5);
    await tester.tap(find.byKey(const Key('onb-allow')));
    await linger(tester, 2.5);
    await tester.tap(find.byKey(const Key('onb-profile-fill')));
    await linger(tester, 2);
    await tester.tap(find.byKey(const Key('med-add')));
    await linger(tester, 1);
    await tester.enterText(find.byKey(const Key('med-0')), 'Insulina');
    await linger(tester, 2);
    await tester.tap(find.byKey(const Key('onb-profile-save')));
    await linger(tester, 2.5);
    await tester.tap(find.byKey(const Key('onb-start')));
    await linger(tester, 2.5);
    final container = ProviderScope.containerOf(tester.element(find.byType(BezpiecznikApp)));
    container.read(appRouterProvider).go('/ustawienia/profil');
    await linger(tester, 3.5);
    expect(find.text('Insulina'), findsWidgets);
    mark('onboarding_end');
  });

  testWidgets('1 offline question -> sourced answer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(await onboardedProfileStore()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    mark('answer');
    await linger(tester, 1.5);
    await typeAndSend(tester, 'Co spakować do plecaka ewakuacyjnego?');
    final ok = await pumpUntil(tester, find.textContaining('▸ '), timeout: const Duration(seconds: 40));
    expect(ok, isTrue);
    await linger(tester, 5);
    await typeAndSend(tester, 'przepis na pierogi');
    await pumpUntil(tester, find.textContaining('Pomagam tylko w sytuacjach kryzysowych'), timeout: const Duration(seconds: 15));
    await linger(tester, 4);
    mark('answer_end');
  });

  testWidgets('2 "dziecko nie oddycha" -> card -> CPR instructor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(await onboardedProfileStore()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          callLauncherProvider.overrideWithValue((u) async => true),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    mark('cpr');
    await linger(tester, 1.5);
    await typeAndSend(tester, 'dziecko nie oddycha');
    expect(await pumpUntil(tester, find.text('Do weryfikacji'), timeout: const Duration(seconds: 3)), isTrue);
    await linger(tester, 4);
    final start = find.text(cprStartLabel, skipOffstage: false);
    if (start.evaluate().isNotEmpty) {
      await tester.ensureVisible(start.first);
      await linger(tester, 1.5);
      await tester.tap(start.first);
    }
    await linger(tester, 9);
    mark('cpr_end');
  });

  testWidgets('3 SOS -> CallPanel -> Powiadom bliskich', (tester) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(await profileWithIce()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          callLauncherProvider.overrideWithValue((u) async {
            launched.add(u);
            return true;
          }),
          canSendSmsProvider.overrideWith((_) async => true),
          callGpsProvider.overrideWith(
            (_) => Stream.value(CallGps(access: LocationAccess.granted, position: FakeLocationGateway.szczecin, fresh: true)),
          ),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.text('Co się dzieje?'));
    mark('sos');
    await linger(tester, 2);
    await tester.tap(find.bySemanticsLabel('SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.'));
    expect(await pumpUntil(tester, find.text('ZADZWOŃ 112')), isTrue);
    await linger(tester, 4);
    await tester.ensureVisible(find.byKey(const Key('call-notify')));
    await linger(tester, 1);
    await tester.tap(find.byKey(const Key('call-notify')));
    await linger(tester, 3);
    expect(launched.single.scheme, 'sms');
    debugPrint('DEMO_SMS ${launched.single}');
    mark('sos_end');
  });

  testWidgets('4 "gdzie schron" -> map card -> map -> compass', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(await onboardedProfileStore()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          fakeLocationOverride,
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    mark('map');
    await linger(tester, 1.5);
    await typeAndSend(tester, 'gdzie jest najbliższy schron');
    expect(await pumpUntil(tester, find.text('Najbliższy schron')), isTrue);
    await linger(tester, 4);
    await tester.ensureVisible(find.byKey(const ValueKey('map-card-open')));
    await tester.tap(find.byKey(const ValueKey('map-card-open')));
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byType(MapScreen).evaluate().isNotEmpty && find.text(preparingTitle).evaluate().isEmpty) break;
    }
    // The card focuses its shelter: the map opens with the PointSheet up.
    final compass = find.text(pointCompassText);
    if (!await pumpUntil(tester, compass, timeout: const Duration(seconds: 8))) {
      final nearestBtn = find.descendant(of: find.byType(MapScreen), matching: find.text(nearestButtonText));
      await tester.tap(nearestBtn.last);
      await linger(tester, 3);
      final first = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('nearest-'),
      );
      await tester.tap(first.first);
      await pumpUntil(tester, compass, timeout: const Duration(seconds: 8));
    }
    await linger(tester, 4);
    await tester.tap(compass.last);
    await pumpUntil(tester, find.byKey(const Key('compass-distance')));
    await linger(tester, 5);
    expect(find.byKey(const Key('compass-distance')), findsOneWidget);
    mark('map_end');
  });
}

class _GrantedGateway implements LocationPermissionGateway {
  @override
  Future<bool> request() async => true;
}
