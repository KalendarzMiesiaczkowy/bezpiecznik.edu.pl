import 'package:bezpiecznik/onboarding/location_gateway.dart';
import 'package:bezpiecznik/onboarding/onboarding_screen.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_screen.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class FakeGateway implements LocationPermissionGateway {
  FakeGateway(this.result);
  final bool result;
  int calls = 0;
  @override
  Future<bool> request() async {
    calls++;
    return result;
  }
}

Future<void> pumpOnboarding(
  WidgetTester tester,
  ProfileStore store,
  FakeGateway gw,
) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('CZAT')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileStoreProvider.overrideWithValue(store),
        locationPermissionGatewayProvider.overrideWithValue(gw),
      ],
      child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  onboardingVisualTests();
  testWidgets('step 2 of 3 shows a 6 dp progress bar filled 2/3', (
    tester,
  ) async {
    await pumpOnboarding(tester, ProfileStore.inMemory(), FakeGateway(true));
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    expect(find.text('Krok 2 z 3'), findsOneWidget);
    final bar = tester.getSize(find.byKey(const Key('onb-progress')));
    final fill = tester.getSize(find.byKey(const Key('onb-progress-fill')));
    expect(bar.height, 6);
    expect(fill.width / bar.width, closeTo(2 / 3, 0.001));
    // The fill must be as tall as the track (it was 0 dp high, invisible).
    expect(fill.height, 6);
  });

  testWidgets('skip path: no profile saved, onboarding completed, chat opens', (
    tester,
  ) async {
    final store = ProfileStore.inMemory();
    final gw = FakeGateway(false);
    await pumpOnboarding(tester, store, gw);
    expect(
      find.text('Nie zastępuje 112. W zagrożeniu życia dzwoń pod 112.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-later')));
    await tester.pumpAndSettle();
    expect(gw.calls, 0);
    expect(find.textContaining('Bez lokalizacji nie pokażę'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onb-profile-later')));
    await tester.pumpAndSettle();
    expect(find.text('Gotowe'), findsOneWidget);
    expect(find.text('Profil domu: pominięto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onb-start')));
    await tester.pumpAndSettle();
    expect(find.text('CZAT'), findsOneWidget);
    expect(await store.isOnboardingDone(), isTrue);
    expect(await store.loadProfile(), isNull);
  });

  testWidgets('complete path: permission requested, profile saved', (
    tester,
  ) async {
    final store = ProfileStore.inMemory();
    final gw = FakeGateway(true);
    await pumpOnboarding(tester, store, gw);
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-allow')));
    await tester.pumpAndSettle();
    expect(gw.calls, 1);
    await tester.tap(find.byKey(const Key('onb-profile-fill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('members-adult-plus')));
    await tester.tap(find.byKey(const Key('med-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('med-0')), 'Insulina');
    await tester.tap(find.byKey(const Key('ice-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ice-name-0')), 'Mama');
    await tester.enterText(find.byKey(const Key('ice-phone-0')), '112');
    await tester.pump();
    expect(
      find.text('To numer alarmowy. Wpisz numer bliskiej osoby.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('ice-phone-0')), '600 100 200');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Profil domu'), findsOneWidget);
    expect(find.byKey(const Key('onb-status-done')), findsNWidgets(3));
    final saved = (await store.loadProfile())!;
    expect(saved.members.length, 1);
    expect(saved.medications.single.name, 'Insulina');
    expect(saved.iceContacts.single.phone, '+48600100200');
    await tester.tap(find.byKey(const Key('onb-start')));
    await tester.pumpAndSettle();
    expect(find.text('CZAT'), findsOneWidget);
  });

  testWidgets('E4 shows stored profile and autosaves edits', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ProfileStore.inMemory();
    await store.saveProfile(
      const HouseholdProfile(
        medications: [Medication(name: 'Insulina')],
        home: Home(floor: 7),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileStoreProvider.overrideWithValue(store)],
        child: MaterialApp(theme: buildBzTheme(), home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Insulina'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home-floor')), '101');
    await tester.pump();
    expect(find.text('Wpisz liczbę od -2 do 100.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home-floor')), '3');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect((await store.loadProfile())!.home.floor, 3);
    expect(find.text('Zapisano'), findsOneWidget);
  });
}

void onboardingVisualTests() {
  testWidgets(
    'back button: absent on step 1, present on step 2 and goes back',
    (tester) async {
      await pumpOnboarding(tester, ProfileStore.inMemory(), FakeGateway(false));
      expect(find.bySemanticsLabel('Wróć'), findsNothing);
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Wróć'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Wróć'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onb-next')), findsOneWidget);
    },
  );

  testWidgets('back from profile form returns to the profile prompt', (
    tester,
  ) async {
    await pumpOnboarding(tester, ProfileStore.inMemory(), FakeGateway(false));
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-later')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-profile-fill')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Wróć'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onb-profile-fill')), findsOneWidget);
  });

  testWidgets('112 notice has the warning icon and tint background', (
    tester,
  ) async {
    await pumpOnboarding(tester, ProfileStore.inMemory(), FakeGateway(false));
    expect(find.byKey(const Key('onb-notice-icon')), findsOneWidget);
    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.byKey(const Key('onb-notice-icon')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration! as BoxDecoration).color, isNotNull);
  });

  testWidgets('Gotowe rows share one label x', (tester) async {
    await pumpOnboarding(tester, ProfileStore.inMemory(), FakeGateway(false));
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-later')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-profile-later')));
    await tester.pumpAndSettle();
    final a = tester.getTopLeft(find.text('SOS i karty ratunkowe')).dx;
    final b = tester.getTopLeft(find.text('Profil domu: pominięto')).dx;
    expect(a, b);
    expect(tester.getTopLeft(find.text('Baza wiedzy')).dx, a);
    expect(find.byKey(const Key('onb-status-done')), findsNWidgets(2));
    expect(find.byKey(const Key('onb-status-skipped')), findsOneWidget);
  });
}
