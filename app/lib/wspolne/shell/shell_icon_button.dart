import 'package:material_ui/material_ui.dart';

import '../theme/bz_theme.dart';

/// 48x48 icon button with a screen-reader label, used by the island and Back.
class ShellIconButton extends StatelessWidget {
  const ShellIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SizedBox(
        width: bz.minTouchTarget,
        height: bz.minTouchTarget,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashFactory: NoSplash.splashFactory,
            highlightColor: bz.overlayPress,
            hoverColor: bz.overlayHover,
            child: Icon(icon, size: 22, color: bz.ink100),
          ),
        ),
      ),
    );
  }
}

/// Floating surface shared by island and Back (bg-200, line-150, float shadow).
BoxDecoration shellFloatDecoration(BuildContext context, {bool circle = false}) {
  final bz = context.bz;
  return BoxDecoration(
    color: bz.bg200,
    shape: circle ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: circle ? null : BorderRadius.circular(bz.radiusFull),
    border: Border.all(color: bz.line150),
    boxShadow: bz.shadowFloat,
  );
}
