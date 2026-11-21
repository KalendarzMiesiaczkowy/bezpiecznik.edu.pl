import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

class _Profile extends ProfileNotifier {
  _Profile(this.p);
  final HouseholdProfile p;
  @override
  Future<HouseholdProfile> build() async => p;
}

Position _pos() => Position(
  latitude: 52.22977,
  longitude: 21.01178,
  timestamp: DateTime(2026, 11, 21, 14, 32),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Future<List<Uri>> _pump(WidgetTester tester, HouseholdProfile profile, {bool canSms = true}) async {
  final launched = <Uri>[];
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        callLauncherProvider.overrideWithValue((u) async {
          launched.add(u);
          return true;
        }),
        canSendSmsProvider.overrideWith((_) async => canSms),
        profileProvider.overrideWith(() => _Profile(profile)),
        callGpsProvider.overrideWith((_) => Stream.value(CallGps(access: LocationAccess.granted, position: _pos(), fresh: true))),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: const Scaffold(body: ContactCallPanel(situation: 'RKO')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return launched;
}

void main() {
  final profile = HouseholdProfile(
    members: const [Member(ageGroup: AgeGroup.infant)],
    medications: const [Medication(name: 'insulina')],
    iceContacts: const [IceContact(name: 'Mama', phone: '+48600100200')],
  );

  testWidgets('two buttons min 80 px (grow with text); nothing launched without a tap; emergency numbers visible, More collapsed', (tester) async {
    final launched = await _pump(tester, profile);
    expect(tester.getSize(find.byKey(const Key('call-112'))).height, greaterThanOrEqualTo(80));
    expect(tester.getSize(find.byKey(const Key('call-notify'))).height, greaterThanOrEqualTo(80));
    expect(launched, isEmpty);
    expect(find.byKey(const Key('call-999')), findsOneWidget);
    expect(find.byKey(const Key('call-coords')), findsNothing);
    expect(find.text('SMS z lokalizacją do: Mama'), findsOneWidget);
    expect(find.text('GPS ±12 m'), findsOneWidget);
  });

  testWidgets('112 launches tel:112; SMS launches sms: with ICE and OSM link', (tester) async {
    final launched = await _pump(tester, profile);
    await tester.tap(find.byKey(const Key('call-112')));
    await tester.pump();
    expect(launched.single.toString(), 'tel:112');
    await tester.tap(find.byKey(const Key('call-notify')));
    await tester.pump();
    final sms = launched.last;
    expect(sms.scheme, 'sms');
    expect(sms.path, '+48600100200');
    final body = sms.queryParameters['body']!;
    expect(body, contains('openstreetmap.org/?mlat=52.22977&mlon=21.01178'));
    expect(body, contains('Sytuacja: RKO.'));
    expect(body, contains('Dom: niemowle.'));
  });

  testWidgets('no switch/hints; SMS always includes profile data', (tester) async {
    final launched = await _pump(tester, profile);
    expect(find.byKey(const Key('call-profile-switch')), findsNothing);
    expect(find.textContaining('Przygotuję SMS'), findsNothing);
    await tester.tap(find.byKey(const Key('call-notify')));
    await tester.pump();
    final body = launched.last.queryParameters['body']!;
    expect(body, contains('Dom: niemowle.'));
    expect(body, contains('insulina'));
  });

  testWidgets('999/998/997 tappable without More; More expands coordinates, AML note; copy gives a toast', (tester) async {
    final launched = await _pump(tester, profile);
    expect(find.bySemanticsLabel('Zadzwoń: 999 Pogotowie'), findsOneWidget);
    expect(find.bySemanticsLabel('Zadzwoń: 998 Straż'), findsOneWidget);
    expect(find.bySemanticsLabel('Zadzwoń: 997 Policja'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call-more')));
    await tester.pump();
    expect(find.textContaining('52°13'), findsOneWidget);
    expect(find.text(callAmlNote), findsOneWidget);
    expect(find.text('Co powiedzieć dyspozytorowi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call-998')));
    await tester.pump();
    expect(launched.last.toString(), 'tel:998');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await tester.tap(find.byKey(const Key('call-coords')));
    await tester.pump();
    expect(find.text('Skopiowano współrzędne'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('no ICE contacts: SMS still opens with empty recipient, add-contacts link shown', (tester) async {
    final launched = await _pump(tester, HouseholdProfile.empty);
    expect(find.text('Nie masz kontaktów alarmowych.'), findsNothing);
    expect(find.text('Dodaj kontakty'), findsOneWidget);
    expect(find.byKey(const Key('call-profile-switch')), findsNothing);
    await tester.tap(find.byKey(const Key('call-notify')));
    await tester.pump();
    expect(launched.last.toString(), startsWith('sms:?body='));
  });

  testWidgets('phone without SMS: button disabled with message', (tester) async {
    final launched = await _pump(tester, profile, canSms: false);
    expect(find.text('Ten telefon nie wysyła SMS-ów.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call-notify')));
    await tester.pump();
    expect(launched, isEmpty);
  });
}
