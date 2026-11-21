import 'package:bezpiecznik/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show Key;
import 'package:bezpiecznik/profil/profile_store.dart';

import 'package:bezpiecznik/mapa/map_screen.dart';

import 'support/harness.dart';

/// Fixed pump instead of pumpAndSettle (map and GPS spinners never settle).
Future<void> settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 800));

/// Shell E2E: opens every screen and goes back with the in-app Back button.
/// Run: `flutter test integration_test/shell_test.dart -d emulator-5554`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigate to every screen and back', (tester) async {
    final profile = await onboardedProfileStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileStoreProvider.overrideWithValue(profile)],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.text('Co się dzieje?'));

    final menu = find.bySemanticsLabel('Menu');
    final map = find.bySemanticsLabel('Mapa');
    final back = find.bySemanticsLabel('Wróć');
    final sos = find.bySemanticsLabel(
      'SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.',
    );

    // E1 chat: island, no Back, SOS.
    expect(find.text('Co się dzieje?'), findsOneWidget);
    expect(menu, findsOneWidget);
    expect(back, findsNothing);
    expect(sos, findsOneWidget);

    // E2 via the island map button, then back.
    await tester.tap(map);
    await settle(tester);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(back, findsOneWidget);
    expect(sos, findsOneWidget);
    await tester.tap(back);
    await settle(tester);
    expect(find.text('Co się dzieje?'), findsOneWidget);

    // E3 via the drawer settings icon, E4 via the "Profil" button.
    await tester.tap(menu);
    await settle(tester);
    expect(find.text('Nowy czat'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Ustawienia'));
    await settle(tester);
    expect(find.text('Ustawienia'), findsWidgets);
    expect(find.text('Nowy czat'), findsNothing);
    await tester.tap(find.byKey(const Key('set-profile')));
    await settle(tester);
    expect(back, findsOneWidget);
    await tester.tap(back); // E4 -> E3
    await settle(tester);
    await tester.tap(back); // E3 -> E1
    await settle(tester);
    expect(find.text('Co się dzieje?'), findsOneWidget);
    expect(menu, findsOneWidget);

    // P2 via SOS tap, closed with its close button.
    await tester.tap(sos);
    await settle(tester);
    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zamknij'));
    await settle(tester);
    expect(find.text('Kontakt ze służbami'), findsNothing);
  
    // System Back with P1 open on E1 closes P1 and keeps E1 (not the app).
    await tester.tap(menu);
    await settle(tester);
    expect(find.text('Nowy czat'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Nowy czat'), findsNothing);
    expect(find.text('Co się dzieje?'), findsOneWidget);

    // Same for P2 opened on E1.
    await tester.tap(sos);
    await settle(tester);
    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Kontakt ze służbami'), findsNothing);
    expect(find.text('Co się dzieje?'), findsOneWidget);
  });
}
