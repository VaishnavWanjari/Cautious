/// Dynamic weather rendered as a Flutter overlay above the game canvas (kept out
/// of Flame so it always covers the screen regardless of camera). Supports rain
/// and wind per the level's `weather` field.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/level_model.dart';

class WeatherOverlay extends StatefulWidget {
  const WeatherOverlay({super.key, required this.weather});
  final Weather weather;

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weather == Weather.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _WeatherPainter(widget.weather, _c.value),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.weather, this.t);
  final Weather weather;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    if (weather == Weather.rain) {
      final paint = Paint()
        ..color = const Color(0xFFB3E5FC).withValues(alpha: 0.5)
        ..strokeWidth = 2;
      for (var i = 0; i < 90; i++) {
        final x0 = rng.nextDouble() * size.width;
        final phase = rng.nextDouble();
        final y = ((t + phase) % 1.0) * (size.height + 40) - 20;
        canvas.drawLine(Offset(x0, y), Offset(x0 - 6, y + 18), paint);
      }
    } else if (weather == Weather.wind) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 22; i++) {
        final phase = rng.nextDouble();
        final y = rng.nextDouble() * size.height;
        final x = ((t + phase) % 1.0) * (size.width + 160) - 80;
        final path = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 30, y - 8, x + 60, y);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.weather != weather;
}
