/// Litterer — the Phase 1 enemy. Walks/patrols, drifts toward Shefali when she
/// is near, and shouts a Hindi line. It is never killed: an aura cure converts
/// it (bad -> good) into a friendly NPC that may drop a Magaj seed. Placeholder
/// art; drop sprites under assets/sprites/enemies/ to replace.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../shefali_game.dart';

class Litterer extends PositionComponent with HasGameReference<ShefaliGame> {
  Litterer({
    required Vector2 spawn,
    required this.patrol,
    required this.line,
    required this.dropsSeed,
  }) {
    position = spawn.clone();
    anchor = Anchor.bottomCenter;
    size = Vector2(48, 78);
    _spawnX = spawn.x;
  }

  final double patrol;
  final String line;
  final bool dropsSeed;

  static const double aggroRange = 260;

  late final double _spawnX;
  double _dir = 1;
  bool cured = false;
  double _animT = 0;
  bool _spokenOnce = false;

  double get baseSpeed => 60 * game.difficulty.enemySpeedMultiplier;

  Rect get aabb => Rect.fromLTWH(position.x - size.x / 2, position.y - size.y, size.x, size.y);
  Vector2 get worldCenter => Vector2(position.x, position.y - size.y / 2);

  /// Convert this enemy to a friendly NPC. Returns true the first time only.
  bool cure() {
    if (cured) return false;
    cured = true;
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animT += dt;

    if (cured) {
      // Calmly settles in place; gentle idle only.
      return;
    }

    final player = game.player;
    final dx = player.worldCenter.x - position.x;
    final distX = dx.abs();

    if (distX < aggroRange) {
      // Drift toward Shefali to provoke a cure.
      _dir = dx >= 0 ? 1 : -1;
      if (!_spokenOnce) {
        _spokenOnce = true;
        game.onEnemySpeak(line);
      }
    } else {
      // Patrol around the spawn point.
      if (position.x > _spawnX + patrol) _dir = -1;
      if (position.x < _spawnX - patrol) _dir = 1;
    }

    position.x += _dir * baseSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final sway = math.sin(_animT * (cured ? 3 : 8)) * (cured ? 1.5 : 3);

    final bodyColor = cured ? const Color(0xFF66BB6A) : const Color(0xFF8D6E63);
    final headColor = cured ? const Color(0xFFA5D6A7) : const Color(0xFFBCAAA4);

    // Body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.32, w, h * 0.6),
        const Radius.circular(8),
      ),
      Paint()..color = bodyColor,
    );
    // Head.
    canvas.drawCircle(Offset(w / 2 + sway, h * 0.22), w * 0.26, Paint()..color = headColor);

    if (cured) {
      // Little leaf halo to show "healed".
      final leaf = Paint()..color = const Color(0xFF2E7D32);
      canvas.drawCircle(Offset(w / 2 - 8, h * 0.05), 4, leaf);
      canvas.drawCircle(Offset(w / 2 + 8, h * 0.05), 4, leaf);
    } else {
      // Angry brow.
      canvas.drawRect(
        Rect.fromLTWH(w * 0.32, h * 0.18, w * 0.36, 3),
        Paint()..color = const Color(0xFF3E2723),
      );
    }
  }
}
