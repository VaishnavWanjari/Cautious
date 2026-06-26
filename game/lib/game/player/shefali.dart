/// Shefali — the player. Mario-jump, yoga-jump (higher/floatier, costs energy),
/// crouch, meditate-charge and aura-cure. AABB platformer physics resolved
/// against the level's solid rects (held by the game). Placeholder art is drawn
/// programmatically; drop sprites under assets/sprites/shefali/ to replace it.
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../shefali_game.dart';

class Shefali extends PositionComponent with HasGameReference<ShefaliGame> {
  Shefali({required Vector2 spawn}) {
    position = spawn.clone();
    anchor = Anchor.topLeft;
    size = Vector2(_standWidth, _standHeight);
  }

  static const double _standWidth = 46;
  static const double _standHeight = 92;
  static const double _crouchHeight = 58;

  static const double moveSpeed = 230;
  static const double jumpImpulse = -560;
  static const double yogaJumpImpulse = -740;
  static const double yogaJumpEnergyCost = 6;
  static const double maxFallSpeed = 1300;

  final Vector2 velocity = Vector2.zero();

  int horizontalInput = 0; // -1, 0, 1
  bool crouching = false;
  bool wantsMeditate = false;
  bool onGround = false;
  bool facingRight = true;

  bool _yogaRising = false;
  double _animT = 0;
  double _cureFlash = 0;

  /// True only when actually able to charge aura: still, grounded, not crouched.
  bool get isMeditating =>
      wantsMeditate && onGround && horizontalInput == 0 && velocity.x.abs() < 1;

  Rect get aabb => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  void jump() {
    if (!onGround || crouching) return;
    velocity.y = jumpImpulse;
    onGround = false;
    game.audio.sfx('jump');
    game.haptic();
  }

  void yogaJump() {
    if (!onGround || crouching) return;
    if (!game.energy.spendEnergy(yogaJumpEnergyCost)) return;
    velocity.y = yogaJumpImpulse;
    _yogaRising = true;
    onGround = false;
    game.audio.sfx('yoga_jump');
    game.haptic();
    game.effects.spawnLeaves(position + size / 2);
  }

  /// World-space center, used by effects/aura targeting.
  Vector2 get worldCenter => position + size / 2;

  void setCrouch(bool value) {
    if (value == crouching) return;
    crouching = value;
    final newH = value ? _crouchHeight : _standHeight;
    // Keep feet planted when changing height.
    position.y += size.y - newH;
    size.y = newH;
  }

  /// Flash effect when a cure is released (called by the game).
  void onCureReleased() => _cureFlash = 0.35;

  @override
  void update(double dt) {
    super.update(dt);
    _animT += dt;
    if (_cureFlash > 0) _cureFlash -= dt;

    final speed = crouching ? moveSpeed * 0.4 : moveSpeed;
    velocity.x = horizontalInput * speed;
    if (horizontalInput != 0) facingRight = horizontalInput > 0;

    // Gravity — softened while a yoga jump is still rising (floaty feel).
    final g = game.level.gravity;
    final gravity = (_yogaRising && velocity.y < 0) ? g * 0.55 : g;
    velocity.y += gravity * dt;
    if (velocity.y > maxFallSpeed) velocity.y = maxFallSpeed;
    if (velocity.y >= 0) _yogaRising = false;

    _moveAndCollide(dt);

    if (position.y > game.level.height + 500) {
      game.onPlayerFell();
    }
  }

  void _moveAndCollide(double dt) {
    // Horizontal sweep.
    position.x += velocity.x * dt;
    position.x = position.x.clamp(0.0, game.level.width - size.x);
    for (final r in game.platformRects) {
      if (aabb.overlaps(r)) {
        if (velocity.x > 0) {
          position.x = r.left - size.x;
        } else if (velocity.x < 0) {
          position.x = r.right;
        }
        velocity.x = 0;
      }
    }

    // Vertical sweep.
    onGround = false;
    position.y += velocity.y * dt;
    for (final r in game.platformRects) {
      if (aabb.overlaps(r)) {
        if (velocity.y > 0) {
          position.y = r.top - size.y;
          onGround = true;
        } else if (velocity.y < 0) {
          position.y = r.bottom;
        }
        velocity.y = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final dir = facingRight ? 1.0 : -1.0;
    final bob = onGround && horizontalInput != 0 ? (1.5 * (0.5 + 0.5 * math.sin(_animT * 12))) : 0.0;

    // Meditation / cure aura glow.
    if (isMeditating || _cureFlash > 0) {
      final pulse = 0.5 + 0.5 * math.sin(_animT * 6);
      final auraR = (_cureFlash > 0 ? 90.0 * (_cureFlash / 0.35) : 60.0 + pulse * 10);
      final auraPaint = Paint()
        ..color = (_cureFlash > 0 ? const Color(0xFF9C6BFF) : const Color(0xFF7E57C2))
            .withValues(alpha: _cureFlash > 0 ? 0.45 : 0.25 + pulse * 0.15);
      canvas.drawCircle(Offset(w / 2, h / 2), auraR, auraPaint);
    }

    // Long hair (below waist) behind the body.
    final hairPaint = Paint()..color = const Color(0xFF1B1B1B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.10, w * 0.64, h * 0.78),
        const Radius.circular(10),
      ),
      hairPaint,
    );

    // Body — lavender kurti (or coverall slot color via outfit later).
    final bodyPaint = Paint()..color = const Color(0xFFB39DDB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.34 - bob, w * 0.56, h * 0.42),
        const Radius.circular(8),
      ),
      bodyPaint,
    );

    // Legs — black jeans.
    final legPaint = Paint()..color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.72, w * 0.18, h * 0.26), legPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.54, h * 0.72, w * 0.18, h * 0.26), legPaint);

    // Head — fair skin.
    final headPaint = Paint()..color = const Color(0xFFFFE0B2);
    canvas.drawCircle(Offset(w / 2, h * 0.18 - bob), w * 0.22, headPaint);

    // Facing hint (a little tilak/eye marker offset by direction).
    final eyePaint = Paint()..color = const Color(0xFF4E342E);
    canvas.drawCircle(Offset(w / 2 + dir * w * 0.08, h * 0.17 - bob), 2.2, eyePaint);
  }
}
