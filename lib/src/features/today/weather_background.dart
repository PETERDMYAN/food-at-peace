import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/weather.dart';

/// A subtle, full-bleed animated layer that reflects the current weather —
/// falling rain/snow, drifting clouds, a warm sun glow, lightning flashes or
/// rolling fog. Kept low-opacity so it sits behind the UI without fighting it.
class WeatherBackground extends StatefulWidget {
  const WeatherBackground({
    super.key,
    required this.condition,
    this.isDay = true,
  });

  final WeatherCondition condition;
  final bool isDay;

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    final rnd = math.Random(7);
    _particles = List.generate(
      80,
      (_) => _Particle(
        x: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.5 + rnd.nextDouble(),
        scale: 0.6 + rnd.nextDouble(),
        sway: rnd.nextDouble() * 2 * math.pi,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _WeatherPainter(
              condition: widget.condition,
              isDay: widget.isDay,
              t: _controller.value,
              particles: _particles,
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.phase,
    required this.speed,
    required this.scale,
    required this.sway,
  });

  final double x; // 0..1 horizontal position
  final double phase; // 0..1 starting offset down the fall
  final double speed; // relative fall speed
  final double scale; // size/length multiplier
  final double sway; // phase for horizontal drift (snow)
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({
    required this.condition,
    required this.isDay,
    required this.t,
    required this.particles,
  });

  final WeatherCondition condition;
  final bool isDay;
  final double t; // 0..1 loop progress
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    switch (condition) {
      case WeatherCondition.clear:
        _glow(canvas, size, intensity: 1);
        break;
      case WeatherCondition.partlyCloudy:
        _glow(canvas, size, intensity: 0.6);
        _clouds(canvas, size, count: 2);
        break;
      case WeatherCondition.cloudy:
        _clouds(canvas, size, count: 3);
        break;
      case WeatherCondition.fog:
        _fog(canvas, size);
        break;
      case WeatherCondition.drizzle:
        _rain(canvas, size, intensity: 0.5);
        break;
      case WeatherCondition.rain:
        _rain(canvas, size, intensity: 1);
        break;
      case WeatherCondition.snow:
        _snow(canvas, size);
        break;
      case WeatherCondition.thunder:
        _rain(canvas, size, intensity: 1);
        _lightning(canvas, size);
        break;
    }
  }

  void _glow(Canvas canvas, Size size, {required double intensity}) {
    final center = Offset(size.width * 0.82, size.height * 0.10);
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final radius = size.width * (0.5 + 0.04 * pulse);
    final color = isDay ? const Color(0xFFFFC36B) : const Color(0xFF9FB6FF);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.28 * intensity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    if (isDay) {
      final ray = Paint()
        ..color = color.withValues(alpha: 0.10 * intensity)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      const n = 12;
      for (var i = 0; i < n; i++) {
        final a = (i / n) * 2 * math.pi + t * 2 * math.pi * 0.06;
        canvas.drawLine(
          center + Offset(math.cos(a), math.sin(a)) * (size.width * 0.17),
          center + Offset(math.cos(a), math.sin(a)) * (size.width * 0.30),
          ray,
        );
      }
    }
  }

  void _clouds(Canvas canvas, Size size, {required int count}) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < count; i++) {
      final base = (i + 0.4) / count;
      final drift = ((t * (0.18 + i * 0.05) + base) % 1.3) - 0.15;
      final c = Offset(drift * size.width, size.height * (0.08 + 0.10 * i));
      _cloud(canvas, c, size.width * (0.24 + 0.05 * i), paint);
    }
  }

  void _cloud(Canvas canvas, Offset c, double w, Paint p) {
    final h = w * 0.5;
    canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), p);
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(w * 0.26, h * 0.18),
        width: w * 0.7,
        height: h * 0.8,
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-w * 0.26, h * 0.12),
        width: w * 0.7,
        height: h * 0.7,
      ),
      p,
    );
  }

  void _fog(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < 4; i++) {
      final base = i / 4;
      final drift = ((t * (0.1 + i * 0.03) + base) % 1.4) - 0.2;
      final y = size.height * (0.08 + 0.22 * i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            drift * size.width - size.width * 0.2,
            y,
            size.width,
            size.height * 0.11,
          ),
          const Radius.circular(50),
        ),
        paint,
      );
    }
  }

  void _rain(Canvas canvas, Size size, {required double intensity}) {
    final paint = Paint()
      ..color = const Color(0xFFBFD4FF).withValues(alpha: 0.22 * intensity)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final count = (particles.length * intensity).round();
    for (var i = 0; i < count; i++) {
      final p = particles[i];
      final len = 16.0 * p.scale * (0.6 + 0.5 * intensity);
      final span = size.height + len;
      final y = ((p.phase + t * 1.5 * p.speed) % 1) * span - len;
      final x = p.x * size.width;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + len), paint);
    }
  }

  void _snow(Canvas canvas, Size size) {
    for (final p in particles) {
      final span = size.height + 12;
      final y = ((p.phase + t * 0.5 * p.speed) % 1) * span - 12;
      final x =
          p.x * size.width + math.sin(t * 2 * math.pi * p.speed + p.sway) * 12;
      canvas.drawCircle(
        Offset(x, y),
        1.7 * p.scale,
        Paint()..color = Colors.white.withValues(alpha: 0.38),
      );
    }
  }

  void _lightning(Canvas canvas, Size size) {
    // Brief flashes a few times per loop.
    final phase = (t * 3) % 1;
    final flash = phase < 0.06 ? (0.06 - phase) / 0.06 : 0.0;
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.14 * flash),
      );
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.t != t || old.condition != condition || old.isDay != isDay;
}
