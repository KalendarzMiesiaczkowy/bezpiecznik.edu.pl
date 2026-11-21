import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/shell/root_overlay.dart';
import 'package:bezpiecznik/wspolne/shell/shell_panels.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('"Dodaj kontakty" in P2 (root overlay) closes it and opens the profile', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: '/mapa');
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
        child: MaterialApp.router(
          theme: buildBzTheme(),
          routerConfig: router,
          builder: (context, child) => RootOverlay(sosLauncher: (_) async => true, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(shellPanelsProvider.notifier).openContactPanel();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dodaj kontakty'));
    await tester.tap(find.text('Dodaj kontakty'));
    await tester.pumpAndSettle();
    expect(container.read(shellPanelsProvider).contactOpen, isFalse);
    expect(router.routerDelegate.currentConfiguration.uri.path, profileRoutePath);
  });
}
