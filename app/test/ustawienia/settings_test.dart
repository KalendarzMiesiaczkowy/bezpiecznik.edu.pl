import 'package:flutter/rendering.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/ustawienia/app_text_scale.dart';
import 'package:bezpiecznik/ustawienia/settings_screen.dart';
import 'package:bezpiecznik/ustawienia/settings_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:bezpiecznik/wspolne/theme/top_fade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('defaults: AI on, voice on, standard text', () async {
    final s = await SettingsStore.inMemory().load();
    expect(s.noAiMode, isFalse);
    expect(s.voiceEnabled, isTrue);
    expect(s.textSize, TextSizeOption.standard);
  });

  test('store round-trips and clears', () async {
    final store = SettingsStore.inMemory();
    await store.save(const AppSettings(textSize: TextSizeOption.extraLarge, noAiMode: true, voiceEnabled: false));
    final s = await store.load();
    expect(s.textSize.factor, 1.5);
    expect(s.noAiMode, isTrue);
    expect(s.voiceEnabled, isFalse);
    await store.clear();
    expect((await store.load()).noAiMode, isFalse);
  });

  test('providers expose settings', () async {
    final c = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(SettingsStore.inMemory())]);
    addTearDown(c.dispose);
    await c.read(settingsProvider.future);
    expect(c.read(textScaleFactorProvider), 1.0);
    await c.read(settingsProvider.notifier).setTextSize(TextSizeOption.large);
    await c.read(settingsProvider.notifier).setNoAiMode(true);
    expect(c.read(textScaleFactorProvider), 1.25);
    expect(c.read(noAiModeProvider), isTrue);
  });

  testWidgets('AppTextScale multiplies the system scale', (tester) async {
    double? seen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(SettingsStore.inMemory())],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
          child: AppTextScale(
            child: Builder(
              builder: (ctx) {
                seen = MediaQuery.textScalerOf(ctx).scale(10);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(seen, closeTo(12, 1e-9));
  });

  group('screen', () {
    late SettingsStore settings;
    late ProfileStore profile;
    late ChatStore chats;

    Future<ProviderContainer> pump(WidgetTester tester) async {
      settings = SettingsStore.inMemory();
      profile = ProfileStore.inMemory();
      chats = ChatStore.inMemory();
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(settings),
          profileStoreProvider.overrideWithValue(profile),
          chatStoreProvider.overrideWithValue(chats),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildBzTheme(), home: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('text size labels never wrap at 360 dp and 1.5x scale', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(SettingsStore.inMemory()),
          profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildBzTheme(),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final single = tester.renderObject<RenderParagraph>(find.byKey(const Key('set-text-size-large'))).size.height;
      for (final o in TextSizeOption.values) {
        final f = find.byKey(Key('set-text-size-${o.name}'));
        final para = tester.renderObject<RenderParagraph>(f);
        expect(para.size.height, single, reason: '${o.label} must be one line');
        expect(tester.getSize(find.ancestor(of: f, matching: find.byType(Container)).first).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('top fade sits above the list (BG72)', (tester) async {
      await pump(tester);
      expect(find.byType(TopFade), findsOneWidget);
    });

    testWidgets('shows MVP rows, hides theme row', (tester) async {
      await pump(tester);
      for (final t in ['Profil domu', 'Tryb bez AI', 'Rozmiar tekstu', 'Głos instrukcji', 'Usuń wszystkie dane', 'Poradniki i źródła']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Motyw'), findsNothing);
      expect(find.text('Wersja'), findsNothing);
      expect(find.text('1.0.0'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('set-about')), matching: find.byType(CustomPaint)), findsOneWidget);
      expect(find.text('Bezpiecznik nie zastępuje 112 ani służb.'), findsOneWidget);
    });

    testWidgets('no-AI toggle and text size persist', (tester) async {
      final c = await pump(tester);
      expect(c.read(noAiModeProvider), isFalse);
      await tester.tap(find.byKey(const Key('set-no-ai')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set-text-size-extraLarge')));
      await tester.pumpAndSettle();
      expect(c.read(noAiModeProvider), isTrue);
      expect(c.read(textScaleFactorProvider), 1.5);
      final saved = await settings.load();
      expect(saved.noAiMode, isTrue);
      expect(saved.textSize, TextSizeOption.extraLarge);
    });

    testWidgets('"Poradniki i źródła" opens the guides screen', (tester) async {
      final router = GoRouter(
        initialLocation: '/ustawienia',
        routes: [
          GoRoute(path: '/ustawienia', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/poradniki', builder: (_, _) => const Text('GUIDES')),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(SettingsStore.inMemory()),
            profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
            chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          ],
          child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set-sources')));
      await tester.pumpAndSettle();
      expect(find.text('GUIDES'), findsOneWidget);
    });

    testWidgets('delete all: cancel keeps data, confirm wipes', (tester) async {
      final c = await pump(tester);
      await profile.saveProfile(const HouseholdProfile(home: Home(floor: 2)));
      await profile.setOnboardingDone(true);
      await chats.saveMessage('c1', StoredMessage(id: 'm1', role: ChatRole.user, text: 'hej', createdAt: DateTime(2026)));
      await c.read(settingsProvider.notifier).setNoAiMode(true);

      await tester.tap(find.byKey(const Key('set-delete-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(await chats.listChats(), hasLength(1));

      await tester.tap(find.byKey(const Key('set-delete-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('set-delete-all-confirm')));
      await tester.pumpAndSettle();
      expect(await chats.listChats(), isEmpty);
      expect(await profile.loadProfile(), isNull);
      expect(await profile.isOnboardingDone(), isFalse);
      expect((await settings.load()).noAiMode, isFalse);
      expect(c.read(noAiModeProvider), isFalse);
    });
  });
}
