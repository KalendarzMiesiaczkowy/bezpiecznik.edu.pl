import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/drawer/chat_drawer.dart';
import 'package:bezpiecznik/czat/drawer/drawer_groups.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/wspolne/shell/cpr_state.dart';
import 'package:bezpiecznik/wspolne/shell/shell_panels.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

ChatSummary _chat(String id, String title, DateTime at) =>
    ChatSummary(id: id, title: title, createdAt: at, updatedAt: at);

/// Renders the drawer plus the shell dialog layer (normally in RootOverlay).
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialog = ref.watch(shellPanelsProvider).dialog;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(left: 0, top: 0, bottom: 0, width: 320, child: ChatDrawer()),
          if (dialog != null) Positioned.fill(child: Center(child: Builder(builder: dialog))),
        ],
      ),
    );
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, ChatStore store) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Host()),
      GoRoute(path: '/ustawienia', builder: (_, _) => const Text('SETTINGS')),
      GoRoute(path: '/poradniki', builder: (_, _) => const Text('GUIDES')),
    ],
  );
  final container = ProviderContainer(
    overrides: [chatStoreProvider.overrideWithValue(store), appRouterProvider.overrideWithValue(router)],
  );
  addTearDown(container.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _send(ProviderContainer c, ChatStore store, String id, String text, DateTime at) async {
  await store.saveMessage(id, StoredMessage(id: 'm-$id', role: ChatRole.user, text: text, createdAt: at));
  c.read(chatRevisionProvider.notifier).bump();
}

void main() {
  group('groupChats', () {
    final now = DateTime(2026, 11, 21, 10);
    test('Dziś / Wczoraj / date headings keep order', () {
      final s = groupChats([
        _chat('a', 'A', DateTime(2026, 11, 21, 9)),
        _chat('b', 'B', DateTime(2026, 11, 21, 8)),
        _chat('c', 'C', DateTime(2026, 11, 20, 23, 59)),
        _chat('d', 'D', DateTime(2026, 11, 18)),
        _chat('e', 'E', DateTime(2025, 10, 2)),
      ], now);
      expect(s.map((e) => e.heading), ['Dziś', 'Wczoraj', '18 lis', '2 paź']);
      expect(s.first.chats.map((c) => c.id), ['a', 'b']);
    });
    test('empty list', () => expect(groupChats([], now), isEmpty));
    test('yesterday across a month boundary', () {
      expect(dayHeading(DateTime(2026, 10, 31), DateTime(2026, 11, 1)), 'Wczoraj');
    });
  });

  testWidgets('empty state, fixed texts, 48 dp rows', (tester) async {
    await _pump(tester, ChatStore.inMemory());
    expect(find.text(drawerEmpty), findsOneWidget);
    expect(find.text(drawerPrivacyNote), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('drawer-logo')), matching: find.byType(CustomPaint)), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('drawer-logo'))), const Size(36, 36));
    expect(tester.getSize(find.bySemanticsLabel(drawerNewChat)).height, 48);
    expect(tester.getSize(find.bySemanticsLabel(drawerSettings)).height, 48);
  });

  testWidgets('"Poradniki i źródła" opens the guides screen', (tester) async {
    await _pump(tester, ChatStore.inMemory());
    await tester.tap(find.byKey(const Key('drawer-sources')));
    await tester.pumpAndSettle();
    expect(find.text('GUIDES'), findsOneWidget);
  });

  testWidgets('logo ignores the text scaler (BG71)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, ChatStore.inMemory());
    final ctx = tester.element(find.descendant(of: find.byKey(const Key('drawer-logo')), matching: find.byType(CustomPaint)));
    expect(MediaQuery.textScalerOf(ctx), TextScaler.noScaling);
    expect(tester.getSize(find.byKey(const Key('drawer-logo'))), const Size(36, 36));
  });

  testWidgets('lists chats by day, title only, newest first; current is selected', (tester) async {
    final store = ChatStore.inMemory();
    final c = await _pump(tester, store);
    final now = DateTime.now();
    await _send(c, store, 'old', 'Plan 72 h', now.subtract(const Duration(days: 40)));
    await _send(c, store, 'new', 'Ktoś nie oddycha', now);
    await tester.pumpAndSettle();
    expect(find.text('Dziś'), findsOneWidget);
    expect(find.text('Ktoś nie oddycha'), findsOneWidget);
    expect(find.text('Plan 72 h'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ktoś nie oddycha')).dy,
      lessThan(tester.getTopLeft(find.text('Plan 72 h')).dy),
    );
    expect(tester.getSize(find.bySemanticsLabel('Plan 72 h. Przytrzymaj, aby usunąć.')).height, 48);
    await tester.tap(find.text('Plan 72 h'));
    await tester.pumpAndSettle();
    expect(c.read(chatControllerProvider).chatId, 'old');
    expect(c.read(shellPanelsProvider).drawerOpen, isFalse);
  });

  testWidgets('create two chats and switch between them', (tester) async {
    final store = ChatStore.inMemory();
    final c = await _pump(tester, store);
    final chat = c.read(chatControllerProvider.notifier);
    await _send(c, store, 'one', 'Pierwszy czat', DateTime.now());
    await _send(c, store, 'two', 'Drugi czat', DateTime.now());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pierwszy czat'));
    await tester.pumpAndSettle();
    expect(c.read(chatControllerProvider).chatId, 'one');
    expect(c.read(chatControllerProvider).messages.single.text, 'Pierwszy czat');
    await tester.tap(find.text('Drugi czat'));
    await tester.pumpAndSettle();
    expect(c.read(chatControllerProvider).chatId, 'two');
    expect(c.read(chatControllerProvider).messages.single.text, 'Drugi czat');
    expect(chat, isNotNull);
  });

  testWidgets('"Nowy czat" starts an empty chat; on an empty chat it only closes', (tester) async {
    final store = ChatStore.inMemory();
    final c = await _pump(tester, store);
    await _send(c, store, 'one', 'Pierwszy czat', DateTime.now());
    await c.read(chatControllerProvider.notifier).openChat('one');
    c.read(shellPanelsProvider.notifier).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(drawerNewChat));
    await tester.pumpAndSettle();
    expect(c.read(chatControllerProvider).isEmpty, isTrue);
    expect(c.read(shellPanelsProvider).drawerOpen, isFalse);
    final before = c.read(chatControllerProvider);
    c.read(shellPanelsProvider.notifier).openDrawer();
    await tester.tap(find.bySemanticsLabel(drawerNewChat));
    await tester.pumpAndSettle();
    expect(identical(c.read(chatControllerProvider), before), isTrue);
    expect(c.read(shellPanelsProvider).drawerOpen, isFalse);
  });

  testWidgets('long press asks, "Usuń" deletes the current chat for good', (tester) async {
    final store = ChatStore.inMemory();
    final c = await _pump(tester, store);
    await _send(c, store, 'one', 'Do usunięcia', DateTime.now());
    await c.read(chatControllerProvider.notifier).openChat('one');
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Do usunięcia'));
    await tester.pumpAndSettle();
    expect(find.text('Usunąć czat?'), findsOneWidget);
    expect(find.text('„Do usunięcia” zniknie z telefonu na zawsze.'), findsOneWidget);
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(await store.listChats(), hasLength(1));
    await tester.longPress(find.text('Do usunięcia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();
    expect(await store.listChats(), isEmpty);
    expect(c.read(chatControllerProvider).isEmpty, isTrue);
    expect(find.text(drawerEmpty), findsOneWidget);
  });

  testWidgets('chat with running CPR cannot be deleted', (tester) async {
    final store = ChatStore.inMemory();
    final c = await _pump(tester, store);
    await _send(c, store, 'one', 'RKO', DateTime.now());
    await c.read(chatControllerProvider.notifier).openChat('one');
    c.read(cprProvider.notifier).start();
    await tester.pumpAndSettle();
    await tester.longPress(find.text('RKO'));
    await tester.pump();
    expect(find.text(drawerCprBlocked), findsOneWidget);
    expect(find.text('Usunąć czat?'), findsNothing);
    c.read(cprProvider.notifier).stop();
  });

  testWidgets('settings row closes the drawer and opens settings', (tester) async {
    final c = await _pump(tester, ChatStore.inMemory());
    c.read(shellPanelsProvider.notifier).openDrawer();
    await tester.tap(find.bySemanticsLabel(drawerSettings));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(c.read(shellPanelsProvider).drawerOpen, isFalse);
  });
}
