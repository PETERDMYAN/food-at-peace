import 'package:flutter/material.dart';

/// An Instagram-story-style circular avatar: a sweep-gradient ring around a
/// solid initials (or icon) bubble. Used for the Circle of Food friend strip.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    this.initials,
    this.icon,
    this.size = 60,
    this.ring = true,
    this.muted = false,
    this.onTap,
    this.badgeCount = 0,
    this.colorSeed,
  });

  final String? initials;
  final IconData? icon;
  final double size;

  /// Whether to draw the gradient story ring (false = plain bubble, e.g. "Add").
  final bool ring;

  /// Dim the ring (e.g. pending/outgoing invites).
  final bool muted;
  final VoidCallback? onTap;
  final int badgeCount;

  /// Drives the bubble colour (so each friend is consistent).
  final int? colorSeed;

  static const _ring = SweepGradient(
    colors: [
      Color(0xFFFEDA75),
      Color(0xFFFA7E1E),
      Color(0xFFD62976),
      Color(0xFF962FBF),
      Color(0xFF4F5BD5),
      Color(0xFFFEDA75),
    ],
  );

  static const _palette = [
    Color(0xFF7C5CFF),
    Color(0xFFE85CC4),
    Color(0xFF3FB36A),
    Color(0xFF2E9BFF),
    Color(0xFFFF8A3D),
    Color(0xFF00B5AD),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = ring
        ? _palette[(colorSeed ?? 0).abs() % _palette.length]
        : scheme.surfaceContainerHighest;
    final inner = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bubbleColor),
      child: icon != null
          ? Icon(icon, color: ring ? Colors.white : scheme.onSurfaceVariant, size: size * 0.42)
          : Text(
              initials ?? '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34,
              ),
            ),
    );

    Widget avatar = ring
        ? Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: muted ? null : _ring,
              color: muted ? scheme.outline : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
              ),
              child: inner,
            ),
          )
        : DottedCircle(size: size + 9, color: scheme.outline, child: inner);

    if (badgeCount > 0) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              alignment: Alignment.center,
              child: Text(
                '$badgeCount',
                style: TextStyle(
                  color: scheme.onError,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return onTap == null
        ? avatar
        : GestureDetector(onTap: onTap, child: avatar);
  }
}

/// A dashed circle border used for the "Add" bubble.
class DottedCircle extends StatelessWidget {
  const DottedCircle({
    super.key,
    required this.size,
    required this.color,
    required this.child,
  });

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final r = size.width / 2 - 1;
    final center = Offset(size.width / 2, size.height / 2);
    const dashes = 26;
    const gap = 0.45;
    final sweep = (2 * 3.14159265 / dashes);
    for (var i = 0; i < dashes; i++) {
      final start = i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        sweep * (1 - gap),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}
