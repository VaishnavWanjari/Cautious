/// Lightweight world-space particle bursts (collect sparkle, landing dust, yoga
/// leaves, aura-cure ring). Kept as a small hand-rolled system so it has no
/// dependency on Flame's particle API surface. Weather (rain/wind) is a separate
/// Flutter overlay (see lib/ui/weather_overlay.dart).
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Added once to the world; spawn methods attach short-lived [Burst]s.
class EffectsManager extends Component {
  final math.Random _rng = math.Random();

  void spawnSparkle(Vector2 at) =>
      add(Burst(at: at, count: 10, color: const Color(0xFFFFF59D), speed: 90, life: 0.5, gravity: -40, rng: _rng));

  void spawnDust(Vector2 at) =>
      add(Burst(at: at, count: 8, color: const Color(0xFFBCAAA4), speed: 60, life: 0.4, gravity: 60, rng: _rng));

  void spawnLeaves(Vector2 at) =>
      add(Burst(at: at, count: 12, color: const Color(0xFF66BB6A), speed: 110, life: 0.8, gravity: 30, rng: _rng));

  void spawnCureRing(Vector2 at) => add(CureRing(at: at));
}

class Burst extends PositionComponent {
  Burst({
    required Vector2 at,
    required this.count,
    required this.color,
    required this.speed,
    required this.life,
    required this.gravity,
    required math.Random rng,
  }) : _rng = rng {
    position = at.clone();
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final s = speed * (0.4 + _rng.nextDouble() * 0.6);
      _particles.add(_P(Vector2(math.cos(a) * s, math.sin(a) * s)));
    }
  }

  final int count;
  final Color color;
  final double speed;
  final double life;
  final double gravity;
  final math.Random _rng;

  final List<_P> _particles = [];
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    for (final p in _particles) {
      p.vel.y += gravity * dt;
      p.pos.add(p.vel * dt);
    }
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final fade = (1 - _t / life).clamp(0.0, 1.0);
    final paint = Paint()..color = color.withValues(alpha: fade);
    for (final p in _particles) {
      canvas.drawCircle(Offset(p.pos.x, p.pos.y), 3 * fade + 1, paint);
    }
  }
}

class _P {
  _P(this.vel) : pos = Vector2.zero();
  final Vector2 vel;
  final Vector2 pos;
}

/// Expanding ring shown when an aura cure is released.
class CureRing extends PositionComponent {
  CureRing({required Vector2 at}) {
    position = at.clone();
  }

  static const double life = 0.45;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final f = (_t / life).clamp(0.0, 1.0);
    final radius = 30 + f * 110;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * (1 - f) + 1
      ..color = const Color(0xFF9C6BFF).withValues(alpha: (1 - f) * 0.7);
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}
