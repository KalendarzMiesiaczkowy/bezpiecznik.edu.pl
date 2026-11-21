import 'package:material_ui/material_ui.dart';

import 'bz_theme.dart';

/// Solid bg-000 band down to the bottom of the floating Back/SOS row, then a short fade
/// below it, so scrolled content never shows around the buttons (QA-confirm 09c).
/// Place as the last child of a full-screen [Stack].
class TopFade extends StatelessWidget {
  const TopFade({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final statusBar = MediaQuery.paddingOf(context).top;
    final topInset = statusBar + 8 > 48 ? statusBar + 8 : 48.0;
    final height = topInset + 48 + t.space4;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.bg000, t.bg000, t.bg000.withValues(alpha: 0)],
              stops: [0, (topInset + 48) / height, 1],
            ),
          ),
        ),
      ),
    );
  }
}
