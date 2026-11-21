import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_router.dart';
import '../theme/bz_theme.dart';
import 'shell_icon_button.dart';
import 'shell_panels.dart';

/// P1 content placeholder; task C04 replaces it with the real side panel.
class DrawerPlaceholder extends ConsumerWidget {
  const DrawerPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            Text('Panel boczny', style: bz.title),
            const Spacer(),
            ShellIconButton(
              icon: LucideIcons.settings,
              label: 'Ustawienia',
              onTap: () {
                ref.read(shellPanelsProvider.notifier).closeDrawer();
                ref.read(appRouterProvider).go(settingsRoutePath);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// P2 content placeholder; task D06 replaces it with the real contact panel.
class ContactPanelPlaceholder extends ConsumerWidget {
  const ContactPanelPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShellIconButton(
                icon: LucideIcons.x,
                label: 'Zamknij',
                onTap: () => ref.read(shellPanelsProvider.notifier).closeContactPanel(),
              ),
              const SizedBox(width: 8),
              Text('Kontakt ze służbami', style: bz.title),
            ],
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}
