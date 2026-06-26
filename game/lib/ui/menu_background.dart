/// Animated menu backdrop: a dusk-purple gradient with slowly drifting leaves.
/// Shared by the menu/gallery screens to give them an animated, polished feel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class MenuBackground extends StatefulWidget {
  const MenuBackground({super.key, required this.child});
  final Widget child;

  @override
  State<MenuBackground> createState() => _MenuBackgroundState();
}

class _MenuBackgroundState extends State<MenuBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  final List<_Leaf> _leaves = List.generate(18, (i) => _Leaf.random(i));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A4A), Color(0xFF120A24)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _LeafPainter(_c.value, _leaves)),
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

class _Leaf {
  _Leaf(this.x, this.phase, this.scale, this.speed);
  final double x;
  final double phase;
  final double scale;
  final double speed;

  factory _Leaf.random(int seed) {
    final r = math.Random(seed * 7 + 3);
    return _Leaf(r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble(), 0.4 + r.nextDouble());
  }
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.t, this.leaves);
  final double t;
  final List<_Leaf> leaves;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.18);
    for (final leaf in leaves) {
      final progress = (t * leaf.speed + leaf.phase) % 1.0;
      final y = progress * (size.height + 40) - 20;
      final x = leaf.x * size.width + math.sin(progress * math.pi * 4 + leaf.phase * 6) * 24;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2);
      final s = 7.0 * leaf.scale;
      final path = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s, 0, 0, s)
        ..quadraticBezierTo(-s, 0, 0, -s);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeafPainter oldDelegate) => oldDelegate.t != t;
}
