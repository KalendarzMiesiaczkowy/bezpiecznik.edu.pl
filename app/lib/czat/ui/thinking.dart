import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'answer_service.dart';

/// DS `Thinking`: pulsing dot + phase label + skeleton lines. With reduced
/// motion the dot and the skeleton stand still.
class Thinking extends StatefulWidget {
  const Thinking({super.key, required this.phase, this.partialText});

  final ThinkingPhase phase;

  /// Optional streamed preview of the answer text.
  final String? partialText;

  @override
  State<Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<Thinking> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.duration = context.bz.durationPulse;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final partial = widget.partialText;
    return Semantics(
      liveRegion: true,
      label: widget.phase.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1).animate(
                  CurvedAnimation(parent: _c, curve: t.easeInOut),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: t.ink100, shape: BoxShape.circle),
                  child: const SizedBox(width: 12, height: 12),
                ),
              ),
              SizedBox(width: t.space3),
              Flexible(
                child: Text(
                  widget.phase.label,
                  key: const Key('thinking-label'),
                  style: t.chat.copyWith(fontSize: 15, height: 22 / 15, color: t.ink200),
                ),
              ),
            ],
          ),
          SizedBox(height: t.space3),
          if (partial != null && partial.isNotEmpty)
            Text(partial, key: const Key('thinking-partial'), style: t.chat.copyWith(color: t.ink200))
          else ...[
            _Line(widthFactor: 1, c: _c),
            SizedBox(height: t.space2),
            _Line(widthFactor: 0.6, c: _c),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.widthFactor, required this.c});

  final double widthFactor;
  final Animation<double> c;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusFull),
            gradient: LinearGradient(
              colors: [t.bg200, t.bg300, t.bg200],
              stops: [0, c.value, 1],
            ),
          ),
        ),
      ),
    );
  }
}
