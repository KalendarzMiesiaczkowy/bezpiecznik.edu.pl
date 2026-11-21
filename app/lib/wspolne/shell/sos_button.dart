import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../theme/bz_theme.dart';
import 'shell_panels.dart';

/// Exact screen-reader label required by the spec.
const sosSemanticsLabel = 'SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.';

/// How long SOS must be held to dial 112.
const sosHoldDuration = Duration(milliseconds: 800);

typedef UriLauncher = Future<bool> Function(Uri uri);

/// `tel:` opens the system dialer (the user confirms the call); the app never
/// calls by itself.
Future<bool> defaultSosLauncher(Uri uri) => launchUrl(uri);

Future<void> defaultSosVibrate() async {
  try {
    await Vibration.vibrate(duration: 200);
  } catch (_) {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}

/// Red SOS button. Tap opens P2; holding [sosHoldDuration] vibrates and opens
/// the dialer with `tel:112`; a ring fills while held; releasing early cancels.
class SosButton extends ConsumerStatefulWidget {
  const SosButton({
    super.key,
    this.launcher = defaultSosLauncher,
    this.vibrate = defaultSosVibrate,
  });

  /// Injectable for tests.
  final UriLauncher launcher;
  final Future<void> Function() vibrate;

  static const double size = 56;

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton> with SingleTickerProviderStateMixin {
  static const _slop = 24.0;

  late final AnimationController _ring;
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _fired = false;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: sosHoldDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _fire();
      });
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    unawaited(widget.vibrate());
    unawaited(widget.launcher(Uri(scheme: 'tel', path: '112')));
  }

  void _openContact() {
    final panels = ref.read(shellPanelsProvider);
    // P2 already open: tap does nothing.
    if (panels.contactOpen) return;
    ref.read(shellPanelsProvider.notifier).openContactPanel();
  }

  void _onDown(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _origin = e.position;
    _fired = false;
    _moved = false;
    _ring.forward(from: 0);
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _moved) return;
    if ((e.position - _origin).distance > _slop) {
      _moved = true;
      _ring.reset();
    }
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final wasTap = !_fired && !_moved;
    _ring.reset();
    if (wasTap) _openContact();
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _moved = true;
    _ring.reset();
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      button: true,
      label: sosSemanticsLabel,
      onTap: _openContact,
      onLongPress: () {
        _fired = false;
        _fire();
      },
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: SizedBox(
          width: SosButton.size,
          height: SosButton.size,
          child: AnimatedBuilder(
            animation: _ring,
            builder: (context, child) => CustomPaint(
              foregroundPainter: _RingPainter(_ring.value, bz.onSos),
              child: child,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bz.sos,
                shape: BoxShape.circle,
                boxShadow: bz.shadowFloat,
              ),
              child: Center(
                child: Text(
                  'SOS',
                  style: bz.label.copyWith(
                    color: bz.onSos,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      -1.5707963267948966,
      6.283185307179586 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
