import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';

/// The B+ mark, paths from the design system Logo (1024 x 1024 viewBox):
/// "B" in ink-100, the "+" in signal.
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.letter, required this.cross});

  final Color letter;
  final Color cross;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024, size.height / 1024);
    final b = Path()
      ..moveTo(95.21765, 91.696941)
      ..relativeLineTo(631.15681, 0)
      ..relativeCubicTo(71.45612, 0, 194.74089, 70.842779, 194.74089, 216.208439)
      ..relativeCubicTo(0, 126.65827, -111.01762, 193.82089, -152.11256, 202.40789)
      ..relativeCubicTo(64.70919, 11.04043, 159.77956, 76.97633, 159.77956, 202.40789)
      ..relativeCubicTo(0, 180.63371, -168.97992, 219.5819, -190.14075, 219.5819)
      ..lineTo(95.21765, 932.303)
      ..close();
    final plus = Path()
      ..moveTo(432.87444, 270.38444)
      ..lineTo(591.12558, 270.38444)
      ..lineTo(591.12558, 432.87443)
      ..lineTo(753.61557, 432.87443)
      ..lineTo(753.61557, 591.12558)
      ..lineTo(591.12558, 591.12558)
      ..lineTo(591.12558, 753.61556)
      ..lineTo(432.87444, 753.61556)
      ..lineTo(432.87444, 591.12558)
      ..lineTo(270.38444, 591.12558)
      ..lineTo(270.38444, 432.87443)
      ..lineTo(432.87444, 432.87443)
      ..close();
    canvas.drawPath(b, Paint()..color = letter);
    canvas.drawPath(plus, Paint()..color = cross);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.letter != letter || old.cross != cross;
}

/// Fixed-size B+ logo; ignores text scaling.
class BzLogo extends StatelessWidget {
  const BzLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return SizedBox(
      width: size,
      height: size,
      child: MediaQuery.withNoTextScaling(
        child: Semantics(
          label: 'Bezpiecznik',
          image: true,
          child: ExcludeSemantics(
            child: CustomPaint(painter: _LogoPainter(letter: bz.ink100, cross: bz.signal)),
          ),
        ),
      ),
    );
  }
}
