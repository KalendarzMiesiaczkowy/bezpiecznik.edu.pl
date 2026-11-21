import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bz_theme.dart';
import 'shell_icon_button.dart';

/// Capsule in the top-left corner of the chat (E1): menu (P1) and map (E2).
class NavIsland extends StatelessWidget {
  const NavIsland({super.key, required this.onMenu, required this.onMap});

  final VoidCallback onMenu;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: shellFloatDecoration(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShellIconButton(icon: LucideIcons.menu, label: 'Menu', onTap: onMenu),
          // DS `.bz-island__sep`.
          SizedBox(width: 1, height: 20, child: ColoredBox(color: context.bz.line150)),
          ShellIconButton(icon: LucideIcons.map, label: 'Mapa', onTap: onMap),
        ],
      ),
    );
  }
}

/// Round Back button replacing the island on E2/E3/E4.
class BzBackButton extends StatelessWidget {
  const BzBackButton({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: shellFloatDecoration(context, circle: true),
      child: ShellIconButton(icon: LucideIcons.arrowLeft, label: 'Wróć', onTap: onBack),
    );
  }
}
