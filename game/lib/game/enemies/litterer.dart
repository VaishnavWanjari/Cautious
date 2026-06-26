/// Litterer — the Phase 1 enemy. It actively chases Shefali and throws trash
/// (which nibbles her energy), shouting funny Hindi taunts. It is never killed:
/// an aura cure converts it (bad -> good) into a calm, friendly NPC and Shefali
/// plants a tree where it stood. Vector art with an optional sprite override
/// (slots 'litterer' / 'litterer_cured').
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
    size = Vector2(52, 84);
    _spawnX = spawn.x;
  }

  final double patrol;
  final String line; // primary taunt id (from the level)
  final bool dropsSeed;

  static const double chaseRange = 640;
  static const double throwRange = 460;
  static const List<String> tauntPool = [
    'enemy_plastic',
    'enemy_environment',
    'enemy_plant',
    'enemy_funny_1',
    'enemy_funny_2',
  ];

  late final double _spawnX;
  final math.Random _rng = math.Random();
  double _dir = 1;
  bool cured = false;
  double _animT = 0;
  double _throwCd = 1.5;
  double _tauntCd = 1.0;
  bool _spokeIntro = false;

  double get baseSpeed => (cured ? 28 : 78) * game.difficulty.enemySpeedMultiplier;

  Rect get aabb => Rect.fromLTWH(position.x - size.x / 2, position.y - size.y, size.x, size.y);
  Vector2 get worldCenter => Vector2(position.x, position.y - size.y / 2);

  /// Convert to a friendly NPC. Returns true the first time only.
  bool cure() {
    if (cured) return false;
    cured = true;
    _dir = -_dir;
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animT += dt;

    if (cured) {
      // Wanders happily near where it was healed.
      if (position.x > _spawnX + 60) _dir = -1;
      if (position.x < _spawnX - 60) _dir = 1;
      position.x += _dir * baseSpeed * dt;
      return;
    }

    final px = game.player.worldCenter.x;
    final dx = px - position.x;
    final distX = dx.abs();

    if (distX < chaseRange) {
      _dir = dx >= 0 ? 1 : -1;
      if (!_spokeIntro) {
        _spokeIntro = true;
        game.onEnemySpeak(line);
      }
      // Throw trash on a cooldown while in range.
      _throwCd -= dt;
      if (distX < throwRange && _throwCd <= 0) {
        _throwCd = 2.2 + _rng.nextDouble();
        game.spawnTrash(worldCenter, _dir);
      }
      // Occasional extra taunt for flavour.
      _tauntCd -= dt;
      if (_tauntCd <= 0) {
        _tauntCd = 4.0 + _rng.nextDouble() * 3;
        game.onEnemySpeak(tauntPool[_rng.nextInt(tauntPool.length)]);
      }
    } else {
      if (position.x > _spawnX + patrol) _dir = -1;
      if (position.x < _spawnX - patrol) _dir = 1;
    }

    position.x += _dir * baseSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y); // local bottom-center as origin
    if (_dir < 0) canvas.scale(-1, 1);
    canvas.translate(-size.x / 2, -size.y);

    final drew = game.art.draw(canvas, cured ? 'litterer_cured' : 'litterer', size);
    if (!drew) _renderVector(canvas);

    canvas.restore();
  }

  void _renderVector(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final sway = math.sin(_animT * (cured ? 3 : 9)) * (cured ? 1.5 : 3);

    final shirt = cured ? const Color(0xFF66BB6A) : const Color(0xFF7E5A43);
    final skin = const Color(0xFFE0B089);

    // Legs.
    final legPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(w * 0.30, h * 0.74, w * 0.16, h * 0.26), legPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.54, h * 0.74, w * 0.16, h * 0.26), legPaint);
    // Torso.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.36, w * 0.56, h * 0.42), const Radius.circular(8)),
      Paint()..color = shirt,
    );
    // Head.
    canvas.drawCircle(Offset(w / 2 + sway, h * 0.22), w * 0.22, Paint()..color = skin);
    // Hair tuft.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w / 2 + sway, h * 0.18), radius: w * 0.24),
      math.pi, math.pi, true, Paint()..color = const Color(0xFF2B1B12),
    );

    if (cured) {
      // Smile + leaf halo.
      final smile = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1B5E20);
      canvas.drawArc(Rect.fromCircle(center: Offset(w / 2 + sway, h * 0.24), radius: 6), 0.2, math.pi - 0.4, false, smile);
      final leaf = Paint()..color = const Color(0xFF2E7D32);
      canvas.drawCircle(Offset(w / 2 - 8, h * 0.02), 4, leaf);
      canvas.drawCircle(Offset(w / 2 + 8, h * 0.02), 4, leaf);
    } else {
      // Angry brow + a trash bag in hand.
      canvas.drawRect(Rect.fromLTWH(w * 0.34, h * 0.18, w * 0.30, 3), Paint()..color = const Color(0xFF3E2723));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.72, h * 0.44, w * 0.22, h * 0.22), const Radius.circular(5)),
        Paint()..color = const Color(0xFF455A64),
      );
    }
  }
}

/// A piece of thrown trash. Arcs toward Shefali; on contact it nibbles her
/// energy. Harmless visual otherwise.
class TrashProjectile extends PositionComponent with HasGameReference<ShefaliGame> {
  TrashProjectile({required Vector2 from, required double dir}) {
    position = from.clone();
    anchor = Anchor.center;
    size = Vector2.all(18);
    _vel = Vector2(dir * 220, -160);
  }

  late Vector2 _vel;
  double _t = 0;
  double _spin = 0;
  bool _spent = false;

  Rect get aabb => Rect.fromLTWH(position.x - size.x / 2, position.y - size.y / 2, size.x, size.y);

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _spin += dt * 8;
    _vel.y += 520 * dt;
    position.add(_vel * dt);

    if (!_spent && game.player.aabb.overlaps(aabb)) {
      _spent = true;
      game.onTrashHit(position.clone());
      removeFromParent();
      return;
    }
    if (_t > 4 || position.y > game.level.height + 100) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(_spin);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y), const Radius.circular(3)),
      Paint()..color = const Color(0xFF6D6D6D),
    );
    canvas.drawRect(Rect.fromLTWH(-size.x / 4, -size.y / 4, size.x / 2, 2), Paint()..color = const Color(0xFF424242));
    canvas.restore();
  }
}
