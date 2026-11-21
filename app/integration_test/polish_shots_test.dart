import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_card.dart';
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
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';

/// Polish screenshots: walks every screen and prints `POLISH_SHOT <name>`;
/// `polish/tools/shots.sh` grabs `adb screencap` on each mark.
/// Real answer path (host LLM), real cards and MBTiles; location, launcher
/// and storage are faked, so no call or SMS ever leaves the emulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> linger(WidgetTester tester, double seconds) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await linger(tester, 1.2);
    debugPrint('POLISH_SHOT $name');
    await linger(tester, 2.5);
  }

  Future<void> scroll(WidgetTester tester, Finder scrollable, double dy) async {
    await tester.drag(scrollable.first, Offset(0, -dy));
    await linger(tester, 0.8);
  }

  Future<ProfileStore> profileWithIce() async {
    final store = await onboardedProfileStore();
    await store.saveProfile(
      const HouseholdProfile(
        medications: [Medication(name: 'Insulina')],
        iceContacts: [IceContact(name: 'Mama', phone: '+48600100200')],
      ),
    );
    return store;
  }

  List<Override> base(ProfileStore store) => [
        profileStoreProvider.overrideWithValue(store),
        chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        callLauncherProvider.overrideWithValue((u) async => true),
        canSendSmsProvider.overrideWith((_) async => true),
        callGpsProvider.overrideWith(
          (_) => Stream.value(CallGps(access: LocationAccess.granted, position: FakeLocationGateway.szczecin, fresh: true)),
        ),
        fakeLocationOverride,
      ];

  Future<void> send(WidgetTester tester, String q) async {
    final field = find.byKey(const Key('composer-field'));
    await tester.tap(field);
    await tester.enterText(field, q);
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
  }

  void go(WidgetTester tester, String path) =>
      ProviderScope.containerOf(tester.element(find.byType(BezpiecznikApp))).read(appRouterProvider).go(path);

  testWidgets('onboarding', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
        locationPermissionGatewayProvider.overrideWithValue(_GrantedGateway()),
        chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
      ],
      child: const BezpiecznikApp(),
    ));
    await pumpUntil(tester, find.byKey(const Key('onb-next')));
    await shot(tester, 'onboarding-1');
    await tester.tap(find.byKey(const Key('onb-next')));
    await shot(tester, 'onboarding-2');
    await tester.tap(find.byKey(const Key('onb-allow')));
    await shot(tester, 'onboarding-3');
    await tester.tap(find.byKey(const Key('onb-profile-fill')));
    await shot(tester, 'onboarding-4');
    await tester.tap(find.byKey(const Key('onb-profile-save')));
    await shot(tester, 'onboarding-5');
  });

  testWidgets('chat', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: base(await profileWithIce()), child: const BezpiecznikApp()));
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    await shot(tester, 'czat-start');
    await tester.tap(find.text('Brak prądu').first);
    await pumpUntil(tester, find.byType(SourceChip), timeout: const Duration(seconds: 60));
    await linger(tester, 2);
    await shot(tester, 'czat-odpowiedz');
    await scroll(tester, find.byKey(const Key('message-list')), 500);
    await shot(tester, 'czat-odpowiedz-2');
    await tester.tap(find.byType(SourceChip).first);
    await shot(tester, 'czat-zrodlo');
    await tester.tapAt(const Offset(20, 120));
    await linger(tester, 1);
    await send(tester, 'przepis na pierogi');
    await pumpUntil(tester, find.textContaining('Pomagam tylko'), timeout: const Duration(seconds: 30));
    await shot(tester, 'czat-poza-zakresem');
    await tester.tap(find.bySemanticsLabel('Menu').first);
    await shot(tester, 'czat-menu');
  });

  testWidgets('rescue card + CPR', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: base(await profileWithIce()), child: const BezpiecznikApp()));
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    await send(tester, 'dziecko nie oddycha');
    await pumpUntil(tester, find.text('Do weryfikacji'), timeout: const Duration(seconds: 5));
    await shot(tester, 'karta-ratunkowa');
    await scroll(tester, find.byKey(const Key('message-list')), 500);
    await shot(tester, 'karta-ratunkowa-2');
    final start = find.text(cprStartLabel, skipOffstage: false);
    await tester.ensureVisible(start.first);
    await tester.tap(start.first);
    await linger(tester, 4);
    await shot(tester, 'rko');
  });

  testWidgets('SOS', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: base(await profileWithIce()), child: const BezpiecznikApp()));
    await pumpUntil(tester, find.text('Co się dzieje?'));
    await tester.tap(find.bySemanticsLabel('SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.'));
    await pumpUntil(tester, find.byKey(const Key('call-112')));
    await shot(tester, 'sos');
    await tester.ensureVisible(find.byKey(const Key('call-more')));
    await tester.tap(find.byKey(const Key('call-more')));
    await linger(tester, 1);
    await shot(tester, 'sos-wiecej');
  });

  testWidgets('map + compass', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: base(await onboardedProfileStore()), child: const BezpiecznikApp()));
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    go(tester, '/mapa');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byType(MapScreen).evaluate().isNotEmpty && find.text(preparingTitle).evaluate().isEmpty) break;
    }
    await linger(tester, 3);
    await shot(tester, 'mapa');
    final nearestBtn = find.descendant(of: find.byType(MapScreen), matching: find.text(nearestButtonText));
    await tester.tap(nearestBtn.last);
    await linger(tester, 2);
    await shot(tester, 'mapa-najblizsze');
    final first = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('nearest-'),
    );
    await tester.tap(first.first);
    await pumpUntil(tester, find.text(pointCompassText), timeout: const Duration(seconds: 8));
    await shot(tester, 'mapa-punkt');
    await tester.tap(find.text(pointCompassText).last);
    await pumpUntil(tester, find.byKey(const Key('compass-distance')));
    await shot(tester, 'kompas');
  });

  testWidgets('profile + settings', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: base(await profileWithIce()), child: const BezpiecznikApp()));
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    go(tester, '/ustawienia');
    await linger(tester, 1.5);
    await shot(tester, 'ustawienia');
    await scroll(tester, find.byType(Scrollable), 700);
    await shot(tester, 'ustawienia-2');
    go(tester, '/ustawienia/profil');
    await linger(tester, 1.5);
    await shot(tester, 'profil');
    await scroll(tester, find.byType(Scrollable), 700);
    await shot(tester, 'profil-2');
    await scroll(tester, find.byType(Scrollable), 700);
    await shot(tester, 'profil-3');
  });
}

class _GrantedGateway implements LocationPermissionGateway {
  @override
  Future<bool> request() async => true;
}
