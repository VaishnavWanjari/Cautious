/// Collectibles: Magaj seeds (hidden score items) and food/energy pickups.
/// Placeholder art; replace via assets/sprites/pickups/.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../logic/food.dart';

class SeedPickup extends PositionComponent {
  SeedPickup({required Vector2 spawn}) {
    position = spawn.clone();
    anchor = Anchor.center;
    size = Vector2.all(22);
  }

  bool collected = false;
  double _t = 0;

  Rect get aabb => Rect.fromLTWH(position.x - size.x / 2, position.y - size.y / 2, size.x, size.y);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final float = math.sin(_t * 3) * 2;
    final r = size.x / 2;
    // Magaj (seed) — pale almond shape with a glow.
    canvas.drawCircle(
      Offset(r, r + float),
      r + 3,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.35),
    );
    canvas.drawCircle(Offset(r, r + float), r * 0.7, Paint()..color = const Color(0xFFCDDC39));
    canvas.drawCircle(Offset(r, r + float), r * 0.4, Paint()..color = const Color(0xFF827717));
  }
}

class FoodPickup extends PositionComponent {
  FoodPickup({required Vector2 spawn, required this.item}) {
    position = spawn.clone();
    anchor = Anchor.center;
    size = Vector2.all(30);
  }

  final FoodItem item;
  bool collected = false;
  double _t = 0;

  Rect get aabb => Rect.fromLTWH(position.x - size.x / 2, position.y - size.y / 2, size.x, size.y);

  Color get _color {
    switch (item.effect) {
      case FoodEffect.fullBoost:
        return const Color(0xFFFFB300);
      case FoodEffect.chill:
        return const Color(0xFF4FC3F7);
      case FoodEffect.restoreEnergy:
        return const Color(0xFFFF8A65);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final float = math.sin(_t * 2.5) * 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, float, size.x, size.y),
        const Radius.circular(6),
      ),
      Paint()..color = _color,
    );
    // Tiny label initial so placeholders are distinguishable.
    final tp = TextPainter(
      text: TextSpan(
        text: item.label.isNotEmpty ? item.label[0] : '?',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, float + (size.y - tp.height) / 2));
  }
}
