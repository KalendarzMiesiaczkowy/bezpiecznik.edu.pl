import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/ustawienia/settings_screen.dart';
import 'package:bezpiecznik/ustawienia/settings_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

/// Settings E2E (C06) on the settings screen alone, with a tiny router that
/// mimics the onboarding redirect. Run: `flutter test integration_test/c06_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<(SettingsStore, ProfileStore, ChatStore)> pump(WidgetTester tester, SettingsStore settings) async {
    final profile = ProfileStore.inMemory();
    await profile.setOnboardingDone(true);
    final chats = ChatStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(settings),
          profileStoreProvider.overrideWithValue(profile),
          chatStoreProvider.overrideWithValue(chats),
        ],
        child: const _TestApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (settings, profile, chats);
  }

  testWidgets('no-AI toggle persists across a restart', (tester) async {
    final settings = SettingsStore.inMemory();
    await pump(tester, settings);
    await tester.tap(find.byKey(const Key('set-no-ai')));
    await tester.pumpAndSettle();
    expect((await settings.load()).noAiMode, isTrue);
    // "Restart": rebuild the whole app on the same store.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, settings);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('set-no-ai'))).value, isTrue);
  });

  testWidgets('delete all wipes data and returns to onboarding', (tester) async {
    final (settings, profile, chats) = await pump(tester, SettingsStore.inMemory());
    await profile.saveProfile(const HouseholdProfile(home: Home(floor: 3)));
    await chats.saveMessage('c1', StoredMessage(id: 'm1', role: ChatRole.user, text: 'hej', createdAt: DateTime(2026)));
    await tester.tap(find.byKey(const Key('set-no-ai')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('set-delete-all')), 200);
    await tester.tap(find.byKey(const Key('set-delete-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-delete-all-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(await chats.listChats(), isEmpty);
    expect(await profile.loadProfile(), isNull);
    expect((await settings.load()).noAiMode, isFalse);
  });
}

class _TestApp extends ConsumerStatefulWidget {
  const _TestApp();

  @override
  ConsumerState<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends ConsumerState<_TestApp> {
  late final GoRouter _router = GoRouter(
    redirect: (_, state) =>
        ref.read(onboardingDoneProvider).value == false && state.uri.path != '/onb' ? '/onb' : null,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/onb', builder: (_, _) => const Scaffold(body: Text('ONBOARDING'))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(onboardingDoneProvider, (_, _) => _router.refresh());
    return MaterialApp.router(theme: buildBzTheme(), routerConfig: _router);
  }
}
