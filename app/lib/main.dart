import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router.dart';
import 'paczki/pack_controller.dart';
import 'ustawienia/app_text_scale.dart';
import 'wspolne/shell/root_overlay.dart';
import 'wspolne/theme/bz_theme.dart';

void main() {
  final container = ProviderContainer();
  runApp(UncontrolledProviderScope(container: container, child: const BezpiecznikApp()));
  // Model and map packs download in the background from the first frame on
  // (and resume on every later start until they are complete).
  unawaited(container.read(packsProvider.notifier).start());
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
      builder: (context, child) => AppTextScale(child: RootOverlay(child: child!)),
    );
  }
}
