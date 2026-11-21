import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/harness.dart';

/// D06 E2E: SOS tap opens Panel 2 with two 80 px buttons; "Więcej" is collapsed
/// and expands. Needs the WIRING (ContactCallPanel in root_overlay).
/// Run: `flutter test integration_test/d06_test.dart -d emulator-5554`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SOS tap opens the contact panel', (tester) async {
    final launched = <Uri>[];
    final profile = await onboardedProfileStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(profile),
          callLauncherProvider.overrideWithValue((u) async {
            launched.add(u);
            return true;
          }),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.text('Co się dzieje?'));

    await tester.tap(
      find.bySemanticsLabel('SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.'),
    );
    await pumpUntil(tester, find.text('ZADZWOŃ 112'));

    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    expect(find.text('ZADZWOŃ 112'), findsOneWidget);
    expect(find.text('POWIADOM BLISKICH'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('call-112'))).height, 80);
    expect(tester.getSize(find.byKey(const Key('call-notify'))).height, 80);
    expect(find.text('999 · Pogotowie'), findsNothing);
    expect(launched, isEmpty);

    await tester.tap(find.byKey(const Key('call-more')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('999 · Pogotowie'), findsOneWidget);
    expect(find.text('Co powiedzieć dyspozytorowi'), findsOneWidget);
    expect(launched, isEmpty);
  });
}
