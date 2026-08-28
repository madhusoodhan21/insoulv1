import 'package:flutter/material.dart';

/// Recreates the prototype's shoe-outline SVG (path + tread strokes) as a
/// CustomPainter, so it can be recolored/animated like the HTML version.
class ShoeIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool glow;

  const ShoeIcon({
    super.key,
    this.size = 48,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size(size, size),
      painter: _ShoePainter(color: color),
    );
    if (!glow) return icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14),
        ],
      ),
      child: icon,
    );
  }
}

class _ShoePainter extends CustomPainter {
  final Color color;
  _ShoePainter({required this.color});

  // Coordinates copied from the HTML's viewBox="0 0 100 100" shoe path.
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final tread = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final outlinePath = Path()
      ..moveTo(20, 70)
      ..cubicTo(18, 55, 22, 40, 34, 30)
      ..cubicTo(42, 23, 52, 22, 60, 26)
      ..cubicTo(70, 31, 78, 40, 82, 52)
      ..cubicTo(85, 61, 83, 68, 76, 71)
      ..cubicTo(60, 78, 36, 78, 20, 70)
      ..close();
    canvas.drawPath(outlinePath, outline);

    void treadLine(double x1, double y1, double x2, double y2) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tread);
    }

    treadLine(28, 62, 32, 52);
    treadLine(36, 65, 41, 53);
    treadLine(45, 67, 50, 54);
    treadLine(55, 68, 60, 55);
    treadLine(65, 68, 69, 56);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShoePainter oldDelegate) =>
      oldDelegate.color != color;
}
