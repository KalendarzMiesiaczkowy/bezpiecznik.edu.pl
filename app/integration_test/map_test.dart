import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:bezpiecznik/mapa/punkty/point_sheet.dart' show nearestButtonText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bezpiecznik/profil/profile_store.dart';

import 'support/harness.dart';

/// Map E2E (gate h2): chat -> island map button -> map (first run copies the
/// MBTiles, up to 30 s) -> attribution visible. Street labels in airplane mode
/// are checked by the coordinator on the screenshot.
/// Location is faked (granted, Szczecin 53.4285, 14.5528): the real permission
/// dialog never gets answered under `flutter test` and would keep the screen on
/// "Przygotowuję mapę…" (map_screen waits for `locationAccessProvider`).
/// The MBTiles install stays real.
/// Run: `flutter test integration_test/map_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open the map from the island and see the attribution', (tester) async {
    final profile = await onboardedProfileStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileStoreProvider.overrideWithValue(profile), fakeLocationOverride],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.bySemanticsLabel('Mapa'));

    await tester.tap(find.bySemanticsLabel('Mapa'));
    await tester.pump();

    // Poll up to 90 s: the first run copies ~100 MB; the progress indicator
    // animates forever, so pumpAndSettle is not usable here.
    final attribution = find.text(attributionText);
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byType(MapScreen).evaluate().isNotEmpty &&
          find.text(preparingTitle).evaluate().isEmpty) {
        break;
      }
    }
    // Let tiles and labels render.
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text(preparingTitle), findsNothing);
    expect(attribution, findsOneWidget);
    expect(find.bySemanticsLabel('Wróć'), findsOneWidget);
    expect(find.text(nearestButtonText), findsOneWidget);
  });
}
