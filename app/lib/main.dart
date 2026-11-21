import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'wspolne/config.dart';

void main() {
  runApp(const ProviderScope(child: BezpiecznikApp()));
}

/// Root widget. The shell (router, theme, overlay) replaces the body in C01/C02.
class BezpiecznikApp extends StatelessWidget {
  const BezpiecznikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bezpiecznik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
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
