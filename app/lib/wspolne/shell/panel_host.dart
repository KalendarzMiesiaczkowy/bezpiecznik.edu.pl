import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/bz_theme.dart';

enum PanelEdge { left, bottom }

/// Animated host for a shell panel: dimmed scrim (tap closes) plus a panel
/// sliding in from [edge]. Renders nothing while fully closed, so a closed
/// panel never takes hits. Animations are skipped when the system asks for
/// reduced motion.
class PanelHost extends StatefulWidget {
  const PanelHost({
    super.key,
    required this.open,
    required this.edge,
    required this.onClose,
    required this.child,
    this.panelKey,
  });

  final bool open;
  final PanelEdge edge;
  final VoidCallback onClose;
  final Widget child;
  final Key? panelKey;

  @override
  State<PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends State<PanelHost> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _c.value = widget.open ? 1 : 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : context.bz.durationBase;
  }

  @override
  void didUpdateWidget(PanelHost old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      final curve = context.bz.easeSheet;
      if (widget.open) {
        _c.animateTo(1, curve: curve);
      } else {
        _c.animateBack(0, curve: curve);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _dragEnd(double velocity, double total) {
    // Swipe towards the closing direction.
    if (velocity < -300 || total < -60) widget.onClose();
    _drag = 0;
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        if (v == 0 && !widget.open) return const SizedBox.shrink();
        final isLeft = widget.edge == PanelEdge.left;
        final size = MediaQuery.sizeOf(context);
        final Widget panel = Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.bottomCenter,
          child: FractionalTranslation(
            translation: isLeft ? Offset(v - 1, 0) : Offset(0, 1 - v),
            child: isLeft
                ? GestureDetector(
                    onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
                    onHorizontalDragEnd: (d) => _dragEnd(d.primaryVelocity ?? 0, _drag),
                    onHorizontalDragCancel: () => _drag = 0,
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: SizedBox(
                        key: widget.panelKey,
                        width: (size.width * 0.85).clamp(0, 360).toDouble(),
                        height: double.infinity,
                        child: Material(color: bz.bg100, child: widget.child),
                      ),
                    ),
                  )
                : GestureDetector(
                    onVerticalDragUpdate: (d) => _drag -= d.delta.dy,
                    onVerticalDragEnd: (d) => _dragEnd(-(d.primaryVelocity ?? 0), _drag),
                    onVerticalDragCancel: () => _drag = 0,
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: SizedBox(
                        key: widget.panelKey,
                        width: double.infinity,
                        // Top edge stays below status bar + SOS row (8 + 56 + 8) and <= 92 %.
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: math.min(
                              size.height * 0.92,
                              size.height - MediaQuery.paddingOf(context).top - 72,
                            ),
                          ),
                          child: Material(
                            color: bz.bg100,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(bz.radiusXl)),
                            child: SafeArea(top: false, child: widget.child),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Zamknij panel',
                onTap: widget.onClose,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: ColoredBox(color: bz.scrim.withValues(alpha: bz.scrim.a * v)),
                ),
              ),
            ),
            Positioned.fill(child: panel),
          ],
        );
      },
    );
  }
}
