/// A tree Shefali plants when she cures a litterer — the visible "clean-up" of
/// the mess. Grows in with a quick pop. Sprite slot 'tree' overrides the vector.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../shefali_game.dart';

class PlantedTree extends PositionComponent with HasGameReference<ShefaliGame> {
  PlantedTree({required Vector2 base}) {
    anchor = Anchor.bottomCenter;
    size = Vector2(70, 110);
    position = base.clone();
  }

  double _grow = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_grow < 1) _grow = (_grow + dt * 2.2).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final s = Curves.easeOutBack.transform(_grow);
    canvas.save();
    // Scale up from the base (bottom-center is the local point (w/2, h)).
    canvas.translate(size.x / 2, size.y);
    canvas.scale(s, s);
    canvas.translate(-size.x / 2, -size.y);

    if (!game.art.draw(canvas, 'tree', size)) {
      // Trunk.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.x * 0.44, size.y * 0.5, size.x * 0.12, size.y * 0.5),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF6D4C41),
      );
      // Foliage — three overlapping blobs.
      final leaf = Paint()..color = const Color(0xFF43A047);
      final leafDark = Paint()..color = const Color(0xFF2E7D32);
      canvas.drawCircle(Offset(size.x * 0.5, size.y * 0.34), size.x * 0.34, leafDark);
      canvas.drawCircle(Offset(size.x * 0.32, size.y * 0.42), size.x * 0.26, leaf);
      canvas.drawCircle(Offset(size.x * 0.68, size.y * 0.42), size.x * 0.26, leaf);
      canvas.drawCircle(Offset(size.x * 0.5, size.y * 0.5), size.x * 0.28, leaf);
      // A couple of fruit dots.
      final fruit = Paint()..color = const Color(0xFFFFB300);
      canvas.drawCircle(Offset(size.x * 0.4, size.y * 0.4), 3, fruit);
      canvas.drawCircle(Offset(size.x * 0.62, size.y * 0.46), 3, fruit);
      // Tiny sparkle.
      final sparkAlpha = 0.6 * (0.5 + 0.5 * math.sin(_grow * math.pi));
      canvas.drawCircle(
        Offset(size.x * 0.5, size.y * 0.1),
        4,
        Paint()..color = const Color(0xFFFFF59D).withValues(alpha: sparkAlpha),
      );
    }
    canvas.restore();
  }
}
