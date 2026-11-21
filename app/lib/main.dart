import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router.dart';
import 'wspolne/shell/root_overlay.dart';
import 'wspolne/theme/bz_theme.dart';

void main() {
  runApp(const ProviderScope(child: BezpiecznikApp()));
}

/// Root widget: router + theme + the shell overlay (SOS, island, panels).
class BezpiecznikApp extends ConsumerWidget {
  const BezpiecznikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Bezpiecznik',
      debugShowCheckedModeBanner: false,
      theme: buildBzTheme(),
      locale: const Locale('pl'),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => RootOverlay(child: child!),
    );
  }
}
