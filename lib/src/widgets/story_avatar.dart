import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// An Instagram-story-style circular avatar: a sweep-gradient ring around a
/// solid initials (or icon) bubble — or the user's photo when [imageBytes] is
/// set. Used for the Circle of Food friend strip + the "You" / profile avatar.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    this.initials,
    this.icon,
    this.imageBytes,
    this.imageUrl,
    this.imageCacheKey,
    this.size = 60,
    this.ring = true,
    this.muted = false,
    this.seen = false,
    this.story = true,
    this.onTap,
    this.badgeCount = 0,
    this.colorSeed,
    this.official = false,
  });

  final String? initials;
  final IconData? icon;

  /// JPEG/PNG bytes of a photo to show in the bubble (e.g. the profile photo).
  final Uint8List? imageBytes;

  /// A network URL for the avatar (e.g. a friend's presigned profile photo).
  /// Used when [imageBytes] is null; falls back to initials on error/while loading.
  final String? imageUrl;

  /// Stable cache key for [imageUrl] (presigned URLs rotate, so cache by a stable
  /// id like the friend id).
  final String? imageCacheKey;
  final double size;

  /// Whether to draw the gradient story ring (false = plain bubble, e.g. "Add").
  final bool ring;

  /// Dim the ring (e.g. pending/outgoing invites).
  final bool muted;

  /// Story already viewed → a plain grey ring instead of the colourful gradient
  /// (Instagram-style "seen" state). Ignored when [ring] is false or [muted].
  final bool seen;

  /// Whether this avatar currently HAS a story to show. False → a plain avatar
  /// with a thin neutral outline (no story ring at all), so a friend who hasn't
  /// shared anything doesn't look like they have stories. Ignored when [ring] is
  /// false. Defaults true (every existing avatar behaves as before).
  final bool story;
  final VoidCallback? onTap;
  final int badgeCount;

  /// Drives the bubble colour (so each friend is consistent).
  final int? colorSeed;

  /// Show a blue "verified" check (an official first-party account, e.g. @roro
  /// or Eva) at the bottom-right.
  final bool official;

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
    final bubble = Container(
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
    final Widget inner = imageBytes != null
        ? ClipOval(
            child: Image.memory(
              imageBytes!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          )
        : (imageUrl != null && imageUrl!.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  cacheKey: imageCacheKey,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => bubble,
                  errorWidget: (_, _, _) => bubble,
                ),
              )
            : bubble);

    final Widget avatar0;
    if (!ring) {
      avatar0 = DottedCircle(size: size + 9, color: scheme.outline, child: inner);
    } else if (!story && !muted) {
      // No active story → a plain avatar with a thin neutral outline. NOT the
      // colourful "unseen" ring (which would falsely signal stories) and NOT the
      // dashed "Add" circle. Same footprint as the ring so the strip stays aligned.
      avatar0 = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface,
          ),
          child: inner,
        ),
      );
    } else {
      avatar0 = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Colourful ring = unseen; plain grey = already viewed (or muted
          // for pending invites).
          gradient: (muted || seen) ? null : _ring,
          color: muted
              ? scheme.outline
              : (seen ? scheme.outlineVariant : null),
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface,
          ),
          child: inner,
        ),
      );
    }
    Widget avatar = avatar0;

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

    if (official) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(1),
              child: Icon(
                Icons.verified,
                size: size * 0.34,
                color: const Color(0xFF2E9BFF),
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
