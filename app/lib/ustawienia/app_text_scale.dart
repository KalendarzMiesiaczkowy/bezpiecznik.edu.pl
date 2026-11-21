import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_store.dart';

/// Multiplies the system font scale by the user's text size. Place it in
/// `MaterialApp.builder`, around the shell, so every screen follows it.
class AppTextScale extends ConsumerWidget {
  const AppTextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = ref.watch(textScaleFactorProvider);
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * factor)),
      child: child,
    );
  }
}
