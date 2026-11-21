import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/shell/cpr_state.dart';
import 'package:bezpiecznik/wspolne/shell/root_overlay.dart';
import 'package:bezpiecznik/wspolne/shell/shell_panels.dart';
import 'package:bezpiecznik/wspolne/shell/sos_button.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

class _App extends ConsumerWidget {
  const _App(this.launcher, this.onNav);

  final UriLauncher launcher;
  final NotificationListenerCallback<NavigationNotification> onNav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      theme: buildBzTheme(),
      routerConfig: ref.watch(appRouterProvider),
      onNavigationNotification: onNav,
      builder: (context, child) =>
          RootOverlay(sosLauncher: launcher, child: child!),
    );
  }
}

class ShellHarness {
  ShellHarness(this.container, this.launched, this.canHandlePop);

  final ProviderContainer container;
  final List<Uri> launched;

  /// Last `canHandlePop` the platform was told (null = never told).
  final List<bool> canHandlePop;

  GoRouter get router => container.read(appRouterProvider);
  ShellPanels get panels => container.read(shellPanelsProvider.notifier);
}

Future<ShellHarness> pumpApp(
  WidgetTester tester, {
  String initial = '/',
  bool Function()? needsOnboarding,
}) async {
  final launched = <Uri>[];
  final canHandlePop = <bool>[];
  final router = createAppRouter(
    initialLocation: initial,
    needsOnboarding: needsOnboarding,
  );
  final container = ProviderContainer(
    overrides: [
      appRouterProvider.overrideWithValue(router),
      profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
      chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _App(
        (uri) async {
          launched.add(uri);
          return true;
        },
        (n) {
          canHandlePop.add(n.canHandlePop);
          return true;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ShellHarness(container, launched, canHandlePop);
}

Finder sos() => find.bySemanticsLabel(sosSemanticsLabel);
Finder menu() => find.bySemanticsLabel('Menu');
Finder mapBtn() => find.bySemanticsLabel('Mapa');
Finder back() => find.bySemanticsLabel('Wróć');

void main() {
  testWidgets('app boots with the real app widget', (tester) async {
    final profiles = ProfileStore.inMemory();
    await profiles.setOnboardingDone(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(profiles),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Co się dzieje?'), findsOneWidget);
    expect(sos(), findsOneWidget);
  });

  testWidgets('island on / and no back button', (tester) async {
    await pumpApp(tester);
    expect(menu(), findsOneWidget);
    expect(mapBtn(), findsOneWidget);
    expect(back(), findsNothing);
    expect(tester.getSize(menu()), const Size(48, 48));
    expect(tester.getSize(mapBtn()), const Size(48, 48));
  });

  for (final path in ['/mapa', '/ustawienia', '/ustawienia/profil']) {
    testWidgets('back button and no island on $path', (tester) async {
      await pumpApp(tester, initial: path);
      expect(back(), findsOneWidget);
      expect(menu(), findsNothing);
      expect(tester.getSize(back()), const Size(48, 48));
    });
  }

  for (final path in [
    '/',
    '/mapa',
    '/ustawienia',
    '/ustawienia/profil',
    '/gallery',
  ]) {
    testWidgets('SOS present on $path, >= 48x48, top-right', (tester) async {
      await pumpApp(tester, initial: path);
      expect(sos(), findsOneWidget);
      final size = tester.getSize(sos());
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.getTopRight(sos()).dx, 800 - 16);
    });
  }

  testWidgets('SOS does not move with the keyboard', (tester) async {
    await pumpApp(tester);
    final before = tester.getTopLeft(sos());
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sos()), before);
    expect(tester.getTopLeft(menu()).dy, lessThan(100));
  });

  testWidgets('tap on SOS drops focus from the composer', (tester) async {
    await pumpApp(tester);
    final field = find.byType(EditableText).first;
    await tester.tap(field);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );
    await tester.tap(sos());
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNull,
    );
    expect(find.text('Kontakt ze służbami'), findsOneWidget);
  });

  testWidgets('tap on SOS opens P2; second tap does nothing', (tester) async {
    final h = await pumpApp(tester);
    await tester.tap(sos());
    await tester.pumpAndSettle();
    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    expect(h.container.read(shellPanelsProvider).contactOpen, isTrue);
    await tester.tap(sos());
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).contactOpen, isTrue);
    expect(h.launched, isEmpty);
  });

  testWidgets(
    'hold < 800 ms does not launch tel and does not open P2 as a tap on release',
    (tester) async {
      final h = await pumpApp(tester);
      final g = await tester.startGesture(tester.getCenter(sos()));
      await tester.pump(const Duration(milliseconds: 500));
      await g.up();
      await tester.pumpAndSettle();
      expect(h.launched, isEmpty);
    },
  );

  testWidgets('moving away before 800 ms cancels the hold', (tester) async {
    final h = await pumpApp(tester);
    final g = await tester.startGesture(tester.getCenter(sos()));
    await g.moveBy(const Offset(-80, 0));
    await tester.pump(const Duration(milliseconds: 900));
    await g.up();
    await tester.pumpAndSettle();
    expect(h.launched, isEmpty);
    expect(h.container.read(shellPanelsProvider).contactOpen, isFalse);
  });

  testWidgets('hold >= 800 ms launches tel:112 once and does not open P2', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    final g = await tester.startGesture(tester.getCenter(sos()));
    await tester.pump(); // the ring ticker starts on the first frame
    await tester.pump(const Duration(milliseconds: 850));
    expect(h.launched, [Uri(scheme: 'tel', path: '112')]);
    expect(h.launched.single.toString(), 'tel:112');
    await tester.pump(const Duration(milliseconds: 500));
    await g.up();
    await tester.pumpAndSettle();
    expect(h.launched, hasLength(1));
    expect(h.container.read(shellPanelsProvider).contactOpen, isFalse);
  });

  testWidgets('drawer opens from the island, closes on backdrop tap', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    expect(find.text('Nowy czat'), findsNothing);
    await tester.tap(menu());
    await tester.pumpAndSettle();
    expect(find.text('Nowy czat'), findsOneWidget);
    await tester.tapAt(const Offset(780, 400)); // scrim, right of the drawer
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).drawerOpen, isFalse);
    expect(find.text('Nowy czat'), findsNothing);
  });

  testWidgets('left-edge swipe on E1 opens the drawer', (tester) async {
    final h = await pumpApp(tester);
    await tester.dragFrom(const Offset(4, 300), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).drawerOpen, isTrue);
  });

  testWidgets(
    'drawer settings icon goes to /ustawienia and closes the drawer',
    (tester) async {
      final h = await pumpApp(tester);
      h.panels.openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('Nowy czat'), findsOneWidget);
      expect(find.byIcon(LucideIcons.settings), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Ustawienia'));
      await tester.pumpAndSettle();
      expect(h.container.read(shellPanelsProvider).drawerOpen, isFalse);
      expect(
        h.router.routerDelegate.currentConfiguration.uri.path,
        '/ustawienia',
      );
      expect(back(), findsOneWidget);
    },
  );

  testWidgets('SOS is hit-testable above an open drawer and above P2', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    h.panels.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(sos());
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).contactOpen, isTrue);
    // P2 above P1: the SOS tap must not have been swallowed by the scrim.
    expect(h.container.read(shellPanelsProvider).drawerOpen, isTrue);
  });

  testWidgets('system back closes P2, then the drawer, then pops the screen', (
    tester,
  ) async {
    final h = await pumpApp(tester, initial: '/');
    h.router.go('/mapa');
    await tester.pumpAndSettle();
    h.panels.openContactPanel();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).contactOpen, isFalse);
    expect(h.router.routerDelegate.currentConfiguration.uri.path, '/mapa');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(menu(), findsOneWidget);

    h.panels.openDrawer();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).drawerOpen, isFalse);
    expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
  });

  testWidgets('framework claims Back while a panel is open on E1', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    expect(h.router.canPop(), isFalse);
    h.canHandlePop.clear();
    h.panels.openDrawer();
    await tester.pumpAndSettle();
    expect(h.canHandlePop.last, isTrue);

    // A Navigator report of "cannot pop" must not override it.
    h.router.go('/');
    h.panels.closeDrawer();
    await tester.pumpAndSettle();
    expect(h.canHandlePop.last, isFalse);

    h.panels.openContactPanel();
    await tester.pumpAndSettle();
    expect(h.canHandlePop.last, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.canHandlePop.last, isFalse);
    expect(menu(), findsOneWidget);
  });

  testWidgets(
    'shell dialog sits above P2 and below SOS; back closes it first',
    (tester) async {
      final h = await pumpApp(tester);
      h.panels.openContactPanel();
      h.panels.openDialog((_) => const Text('Usunąć czat?'));
      await tester.pumpAndSettle();
      expect(find.text('Usunąć czat?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Usunąć czat?'), findsNothing);
      expect(h.container.read(shellPanelsProvider).contactOpen, isTrue);
    },
  );

  testWidgets('E2 pushed over E1 (map card) shows Back, not the island (BG74)', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    h.router.push('/mapa?point=1');
    await tester.pumpAndSettle();
    expect(back(), findsOneWidget);
    expect(menu(), findsNothing);
    await tester.tap(back());
    await tester.pumpAndSettle();
    expect(menu(), findsOneWidget);
    expect(back(), findsNothing);
  });

  testWidgets('back button pops E4 -> E3 -> E1 and E2 -> E1', (tester) async {
    final h = await pumpApp(tester, initial: '/ustawienia/profil');
    String path() => h.router.routerDelegate.currentConfiguration.uri.path;
    await tester.tap(back());
    await tester.pumpAndSettle();
    expect(path(), '/ustawienia');
    await tester.tap(back());
    await tester.pumpAndSettle();
    expect(path(), '/');
    await tester.tap(mapBtn());
    await tester.pumpAndSettle();
    expect(path(), '/mapa');
    await tester.tap(back());
    await tester.pumpAndSettle();
    expect(path(), '/');
  });

  testWidgets('drawer closes when leaving E1', (tester) async {
    final h = await pumpApp(tester);
    h.panels.openDrawer();
    await tester.pumpAndSettle();
    h.router.go('/mapa');
    await tester.pumpAndSettle();
    expect(h.container.read(shellPanelsProvider).drawerOpen, isFalse);
  });

  testWidgets('needsOnboarding hook redirects to E0', (tester) async {
    final h = await pumpApp(tester, needsOnboarding: () => true);
    expect(
      h.router.routerDelegate.currentConfiguration.uri.path,
      '/onboarding',
    );
    expect(menu(), findsNothing);
    expect(back(), findsNothing);
    expect(sos(), findsNothing);
  });

  group('CprIndicator', () {
    testWidgets(
      'hidden on chat, visible on other screens while CPR runs, tap goes to /',
      (tester) async {
        final h = await pumpApp(tester);
        h.container.read(cprProvider.notifier).start();
        addTearDown(() => h.container.read(cprProvider.notifier).stop());
        await tester.pump();
        expect(find.textContaining('RKO'), findsNothing);

        h.router.go('/mapa');
        await tester.pumpAndSettle();
        expect(find.text('● RKO 00:00 · wróć'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        expect(find.text('● RKO 00:03 · wróć'), findsOneWidget);

        await tester.tap(find.textContaining('RKO'));
        await tester.pumpAndSettle();
        expect(h.router.routerDelegate.currentConfiguration.uri.path, '/');
        expect(find.textContaining('RKO'), findsNothing);
      },
    );

    testWidgets('hidden after stop', (tester) async {
      final h = await pumpApp(tester, initial: '/mapa');
      h.container.read(cprProvider.notifier).start();
      await tester.pump();
      expect(find.textContaining('RKO'), findsOneWidget);
      h.container.read(cprProvider.notifier).stop();
      await tester.pump();
      expect(find.textContaining('RKO'), findsNothing);
    });

    test('formatCprElapsed', () {
      expect(
        formatCprElapsed(const Duration(minutes: 3, seconds: 42)),
        '03:42',
      );
      expect(
        formatCprElapsed(const Duration(minutes: 75, seconds: 5)),
        '75:05',
      );
    });
  });

  testWidgets('semantics labels exact', (tester) async {
    await pumpApp(tester);
    expect(
      sosSemanticsLabel,
      'SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.',
    );
  });

  testWidgets('SOS label keeps its design size at 1.5x text scale', (
    tester,
  ) async {
    Future<(double, Size)> measure(double scale) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildBzTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Center(child: SosButton()),
            ),
          ),
        ),
      );
      final text = find.text('SOS');
      final style = tester.widget<Text>(text);
      final scaled = MediaQuery.textScalerOf(tester.element(text))
          .scale(style.style!.fontSize!);
      return (scaled, tester.getSize(text));
    }

    final (base, _) = await measure(1);
    final (big, size) = await measure(1.5);
    expect(big, base);
    expect(size.width, lessThan(SosButton.size));
    expect(size.height, lessThan(SosButton.size));
    expect(find.bySemanticsLabel(sosSemanticsLabel), findsOneWidget);
  });
}
