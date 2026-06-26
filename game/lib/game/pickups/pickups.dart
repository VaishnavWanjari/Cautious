/// Collectibles: Magaj seeds and food/energy pickups. Each is drawn as a
/// recognizable little item (cup of chai, bread-jam slice, magaj seed, …) in
/// vector, or replaced by a sprite if its art slot has a PNG.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../logic/food.dart';
import '../shefali_game.dart';

class SeedPickup extends PositionComponent with HasGameReference<ShefaliGame> {
  SeedPickup({required Vector2 spawn}) {
    position = spawn.clone();
    anchor = Anchor.center;
    size = Vector2.all(26);
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
    canvas.save();
    canvas.translate(0, float);
    // Soft glow.
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x * 0.6,
        Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.3));
    if (!game.art.draw(canvas, 'magaj_seed', size)) {
      // Magaj = a teardrop almond seed, pale beige with a sheen + crease.
      final c = Offset(size.x / 2, size.y / 2);
      final path = Path()
        ..moveTo(c.dx, c.dy - size.y * 0.42)
        ..quadraticBezierTo(c.dx + size.x * 0.42, c.dy, c.dx, c.dy + size.y * 0.42)
        ..quadraticBezierTo(c.dx - size.x * 0.42, c.dy, c.dx, c.dy - size.y * 0.42)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFE8D6A0));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFB59A4D),
      );
      canvas.drawLine(Offset(c.dx, c.dy - size.y * 0.3), Offset(c.dx, c.dy + size.y * 0.3),
          Paint()..strokeWidth = 1..color = const Color(0xFFB59A4D));
      canvas.drawCircle(Offset(c.dx - 3, c.dy - 3), 1.6, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
    canvas.restore();
  }
}

class FoodPickup extends PositionComponent with HasGameReference<ShefaliGame> {
  FoodPickup({required Vector2 spawn, required this.item}) {
    position = spawn.clone();
    anchor = Anchor.center;
    size = Vector2.all(34);
  }

  final FoodItem item;
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
    final float = math.sin(_t * 2.5) * 2;
    canvas.save();
    canvas.translate(0, float);
    if (!game.art.draw(canvas, item.id, size)) {
      FoodIcon.draw(canvas, item.id, size);
    }
    canvas.restore();
  }
}

/// Pure vector drawings for each food id. Reused by the HUD inventory strip too.
class FoodIcon {
  static void draw(Canvas canvas, String id, Vector2 size) {
    final w = size.x;
    final h = size.y;
    switch (id) {
      case 'chai':
        _chai(canvas, w, h);
        break;
      case 'bread_jam':
        _breadJam(canvas, w, h);
        break;
      case 'vada_pav':
        _vadaPav(canvas, w, h);
        break;
      case 'maggi':
        _maggi(canvas, w, h);
        break;
      case 'sushi':
        _sushi(canvas, w, h);
        break;
      default:
        _generic(canvas, w, h);
    }
  }

  static void _chai(Canvas canvas, double w, double h) {
    // Steam.
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawArc(Rect.fromLTWH(w * 0.42, h * 0.02, w * 0.16, h * 0.22), 0, math.pi, false, steam);
    canvas.drawArc(Rect.fromLTWH(w * 0.54, h * 0.02, w * 0.16, h * 0.22), math.pi, math.pi, false, steam);
    // Saucer.
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.16), Paint()..color = const Color(0xFFECEFF1));
    // Cup.
    final cup = Path()
      ..moveTo(w * 0.28, h * 0.42)
      ..lineTo(w * 0.72, h * 0.42)
      ..lineTo(w * 0.64, h * 0.8)
      ..lineTo(w * 0.36, h * 0.8)
      ..close();
    canvas.drawPath(cup, Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.42, w * 0.4, h * 0.1), Paint()..color = const Color(0xFF8D5524)); // tea
    // Handle.
    canvas.drawArc(Rect.fromLTWH(w * 0.66, h * 0.46, w * 0.2, h * 0.24), -math.pi / 2, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white);
  }

  static void _breadJam(Canvas canvas, double w, double h) {
    // Bread slice.
    final bread = Path()
      ..moveTo(w * 0.16, h * 0.5)
      ..quadraticBezierTo(w * 0.16, h * 0.18, w * 0.5, h * 0.18)
      ..quadraticBezierTo(w * 0.84, h * 0.18, w * 0.84, h * 0.5)
      ..lineTo(w * 0.84, h * 0.82)
      ..lineTo(w * 0.16, h * 0.82)
      ..close();
    canvas.drawPath(bread, Paint()..color = const Color(0xFFF1C27D));
    canvas.drawPath(bread, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFC98A3B));
    // Jam.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.36, w * 0.52, h * 0.16), const Radius.circular(6)),
      Paint()..color = const Color(0xFFD32F2F),
    );
  }

  static void _vadaPav(Canvas canvas, double w, double h) {
    // Bun.
    canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.34, Paint()..color = const Color(0xFFE3A857));
    // Vada peeking out.
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.2, Paint()..color = const Color(0xFFB36A1F));
    // Sesame.
    final s = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.4, h * 0.34), 1.4, s);
    canvas.drawCircle(Offset(w * 0.58, h * 0.36), 1.4, s);
  }

  static void _maggi(Canvas canvas, double w, double h) {
    // Bowl.
    canvas.drawArc(Rect.fromLTWH(w * 0.14, h * 0.36, w * 0.72, h * 0.5), 0, math.pi, true,
        Paint()..color = const Color(0xFFEF5350));
    // Noodles.
    final n = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFFFD54F);
    canvas.drawArc(Rect.fromLTWH(w * 0.24, h * 0.3, w * 0.2, h * 0.2), 0, math.pi, false, n);
    canvas.drawArc(Rect.fromLTWH(w * 0.42, h * 0.28, w * 0.22, h * 0.2), 0, math.pi, false, n);
    canvas.drawArc(Rect.fromLTWH(w * 0.58, h * 0.32, w * 0.18, h * 0.2), 0, math.pi, false, n);
  }

  static void _sushi(Canvas canvas, double w, double h) {
    // Nori wrap + rice + filling.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.3, w * 0.52, h * 0.44), const Radius.circular(8)),
        Paint()..color = const Color(0xFF2E3B2E));
    canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.18, Paint()..color = const Color(0xFFFAFAFA));
    canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.07, Paint()..color = const Color(0xFFEF9A9A));
  }

  static void _generic(Canvas canvas, double w, double h) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.6), const Radius.circular(8)),
      Paint()..color = const Color(0xFFFF8A65),
    );
  }
}
