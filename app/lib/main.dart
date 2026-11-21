import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'wspolne/config.dart';
import 'wspolne/theme/bz_theme.dart';
import 'wspolne/theme/gallery_screen.dart';

void main() {
  runApp(const ProviderScope(child: BezpiecznikApp()));
}

/// Root widget. The shell (router, overlay) replaces `home` in C02.
class BezpiecznikApp extends StatelessWidget {
  const BezpiecznikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bezpiecznik',
      debugShowCheckedModeBanner: false,
      theme: buildBzTheme(),
      home: kDebugMode
          ? const GalleryScreen()
          : Scaffold(
              body: Center(
                child: Text(
                  'Bezpiecznik\nLLM: ${llmMode.name}',
                  key: const Key('boot-text'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
