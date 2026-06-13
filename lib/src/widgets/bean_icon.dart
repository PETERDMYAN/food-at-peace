import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Beans mark — a tilted kidney bean filled with the iridescent pastel
/// gradient (gold → mint → sky → lavender). Used wherever a Bean balance/credit
/// is shown.
class BeanIcon extends StatelessWidget {
  const BeanIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BeanPainter(),
    );
  }
}

class _BeanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Kidney-bean silhouette: an oval with a circular notch bitten from one
    // side, tilted slightly.
    final outer = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w * 0.46, h * 0.5),
          width: w * 0.80,
          height: h * 0.94,
        ),
      );
    final notch = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.9, h * 0.46), radius: w * 0.30));
    final bean = Path.combine(PathOperation.difference, outer, notch);

    final fill = Paint()
      ..shader = AppTheme.beanGradient.createShader(rect)
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(w * 0.5, h * 0.5);
    canvas.rotate(-0.55);
    canvas.translate(-w * 0.5, -h * 0.5);
    canvas.drawPath(bean, fill);
    // soft highlight blob for a glossy, jelly-bean feel
    canvas.drawCircle(
      Offset(w * 0.34, h * 0.34),
      w * 0.10,
      Paint()..color = Colors.white.withValues(alpha: 0.55)..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BeanPainter oldDelegate) => false;
}
