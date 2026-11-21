import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Map E2E (gate h2): chat -> island map button -> map (first run copies the
/// MBTiles, up to 30 s) -> attribution visible. Street labels in airplane mode
/// are checked by the coordinator on the screenshot.
/// Run: `flutter test integration_test/map_test.dart -d <device>`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('open the map from the island and see the attribution', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BezpiecznikApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Mapa'));
    await tester.pump();

    // Poll up to 30 s: the first run copies ~100 MB; the progress indicator
    // animates forever, so pumpAndSettle is not usable here.
    final attribution = find.text(attributionText);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
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

    await binding.takeScreenshot('map');
  });
}
