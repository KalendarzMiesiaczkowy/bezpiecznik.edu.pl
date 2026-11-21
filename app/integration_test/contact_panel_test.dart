import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';

/// D06 E2E: SOS tap opens Panel 2; "POWIADOM BLISKICH" records an `sms:` URI to
/// the ICE contact; "ZADZWOŃ 112" records `tel:112`. Nothing launches on open.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SOS tap opens Panel 2, SMS goes to the ICE contact', (tester) async {
    final launched = <Uri>[];
    final store = await onboardedProfileStore();
    await store.saveProfile(
      const HouseholdProfile(
        medications: [Medication(name: 'insulina')],
        iceContacts: [IceContact(name: 'Mama', phone: '+48600100200')],
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(store),
          callLauncherProvider.overrideWithValue((u) async {
            launched.add(u);
            return true;
          }),
          canSendSmsProvider.overrideWith((_) async => true),
          callGpsProvider.overrideWith((_) => Stream.value(const CallGps(access: LocationAccess.denied))),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.text('Co się dzieje?'));

    await tester.tap(find.bySemanticsLabel('SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.'));
    expect(await pumpUntil(tester, find.text('ZADZWOŃ 112')), isTrue);

    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('call-112'))).height, 80);
    expect(tester.getSize(find.byKey(const Key('call-notify'))).height, 80);
    expect(find.text('999 · Pogotowie'), findsNothing);
    expect(launched, isEmpty);

    await tester.tap(find.byKey(const Key('call-notify')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(launched, hasLength(1));
    final sms = launched.single;
    expect(sms.scheme, 'sms');
    expect(sms.path, '+48600100200');
    final body = sms.queryParameters['body']!;
    expect(body, startsWith('SOS. Potrzebuje pomocy.'));
    expect(body, contains('Pozycja: nieznana (brak GPS).'));
    expect(body, contains('Leki: insulina.'));
    expect(body, isNot(contains('Mama')));
    expect(body, isNot(contains('600100200')));

    await tester.tap(find.byKey(const Key('call-112')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(launched.last.toString(), 'tel:112');
  });
}
