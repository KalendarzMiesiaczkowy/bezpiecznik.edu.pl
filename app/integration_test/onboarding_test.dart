import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/onboarding/location_gateway.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:material_ui/material_ui.dart' show Key, Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _GrantedGateway implements LocationPermissionGateway {
  @override
  Future<bool> request() async => true;
}

Widget _app(ProfileStore store) => ProviderScope(
  overrides: [
    profileStoreProvider.overrideWithValue(store),
    locationPermissionGatewayProvider.overrideWithValue(_GrantedGateway()),
    answerServiceProvider.overrideWithValue(FakeAnswerService(delay: const Duration(milliseconds: 50))),
    chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
  ],
  child: const BezpiecznikApp(),
);

/// Run: `flutter test integration_test/onboarding_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh state shows onboarding; skip path reaches chat', (tester) async {
    final store = ProfileStore.inMemory();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.text('Nie zastępuje 112. W zagrożeniu życia dzwoń pod 112.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-later')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-profile-later')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-start')));
    await tester.pumpAndSettle();
    expect(find.text('Co się dzieje?'), findsOneWidget);
    expect(await store.isOnboardingDone(), isTrue);
    expect(await store.loadProfile(), isNull);
  });

  testWidgets('complete path saves a profile that E4 shows', (tester) async {
    final store = ProfileStore.inMemory();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-allow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-profile-fill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('med-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('med-0')), 'Insulina');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb-profile-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb-start')));
    await tester.pumpAndSettle();
    expect(find.text('Co się dzieje?'), findsOneWidget);
    expect((await store.loadProfile())!.medications.single.name, 'Insulina');

    // E4: open via the router (the settings placeholder links to the profile).
    final router = ProviderScope.containerOf(tester.element(find.byType(BezpiecznikApp)));
    router.read(appRouterProvider).go('/ustawienia/profil');
    await tester.pumpAndSettle();
    expect(find.text('Insulina'), findsOneWidget);
  });
}
