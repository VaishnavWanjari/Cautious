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

    // Aura glow (meditation charge + cure flash) — drawn in unflipped space.
    if (isMeditating || _cureFlash > 0) {
      final pulse = 0.5 + 0.5 * math.sin(_animT * 6);
      final auraR = _cureFlash > 0 ? 95.0 * (_cureFlash / 0.35) : 56.0 + pulse * 10;
      canvas.drawCircle(
        Offset(w / 2, h / 2),
        auraR,
        Paint()
          ..color = (_cureFlash > 0 ? const Color(0xFF9C6BFF) : const Color(0xFF7E57C2))
              .withValues(alpha: _cureFlash > 0 ? 0.45 : 0.22 + pulse * 0.14),
      );
    }

    // Sprite override if supplied.
    final slot = isMeditating
        ? 'shefali_meditate'
        : (onGround && horizontalInput != 0 ? 'shefali_run' : 'shefali_idle');
    canvas.save();
    canvas.translate(w / 2, 0);
    if (!facingRight) canvas.scale(-1, 1);
    canvas.translate(-w / 2, 0);
    if (game.art.draw(canvas, slot, size)) {
      canvas.restore();
      return;
    }
    _renderVector(canvas, w, h);
    canvas.restore();
  }

  void _renderVector(Canvas canvas, double w, double h) {
    final bob = onGround && horizontalInput != 0 ? 1.5 * (0.5 + 0.5 * math.sin(_animT * 12)) : 0.0;
    final stride = onGround && horizontalInput != 0 ? math.sin(_animT * 12) : 0.0;

    const skin = Color(0xFFFFD9B0);
    const hair = Color(0xFF161616);
    const kurti = Color(0xFFB39DDB);
    const kurtiDark = Color(0xFF9575CD);
    const legging = Color(0xFF2B2B2B);
    const shoe = Color(0xFFF5F5F5);

    final headC = Offset(w / 2, h * 0.14 - bob);
    final headR = w * 0.2;

    // Long hair behind everything (flares below the waist).
    final hairBack = Path()
      ..moveTo(w * 0.28, h * 0.12)
      ..quadraticBezierTo(w * 0.05, h * 0.5, w * 0.2, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.7, w * 0.8, h * 0.82)
      ..quadraticBezierTo(w * 0.95, h * 0.5, w * 0.72, h * 0.12)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.28, h * 0.12)
      ..close();
    canvas.drawPath(hairBack, Paint()..color = hair);

    if (isMeditating) {
      // Cross-legged lap.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.74, w * 0.64, h * 0.2), const Radius.circular(14)),
        Paint()..color = legging,
      );
    } else {
      // Legs + shoes with a walking stride.
      final lx = w * 0.34 + stride * 5;
      final rx = w * 0.52 - stride * 5;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx, h * 0.72, w * 0.14, h * 0.22), const Radius.circular(5)), Paint()..color = legging);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rx, h * 0.72, w * 0.14, h * 0.22), const Radius.circular(5)), Paint()..color = legging);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(lx - 2, h * 0.93, w * 0.18, h * 0.06), const Radius.circular(4)), Paint()..color = shoe);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rx - 2, h * 0.93, w * 0.18, h * 0.06), const Radius.circular(4)), Paint()..color = shoe);
    }

    // Kurti (tunic) — flared, with a darker hem + side slit shading.
    final kurtiPath = Path()
      ..moveTo(w * 0.28, h * 0.34 - bob)
      ..lineTo(w * 0.72, h * 0.34 - bob)
      ..lineTo(w * 0.82, h * 0.72)
      ..lineTo(w * 0.18, h * 0.72)
      ..close();
    canvas.drawPath(kurtiPath, Paint()..color = kurti);
    canvas.drawRect(Rect.fromLTWH(w * 0.18, h * 0.68, w * 0.64, h * 0.05), Paint()..color = kurtiDark);
    // Sleeves.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.36 - bob, w * 0.12, h * 0.2), const Radius.circular(6)), Paint()..color = kurtiDark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.72, h * 0.36 - bob, w * 0.12, h * 0.2), const Radius.circular(6)), Paint()..color = kurtiDark);
    // Hands.
    canvas.drawCircle(Offset(w * 0.2, h * 0.56 - bob), w * 0.06, Paint()..color = skin);
    canvas.drawCircle(Offset(w * 0.8, h * 0.56 - bob), w * 0.06, Paint()..color = skin);

    // Neck + head.
    canvas.drawRect(Rect.fromLTWH(w * 0.44, h * 0.26 - bob, w * 0.12, h * 0.06), Paint()..color = skin);
    canvas.drawCircle(headC, headR, Paint()..color = skin);
    // Hair top (fringe).
    canvas.drawArc(Rect.fromCircle(center: headC, radius: headR + 1), math.pi, math.pi, true, Paint()..color = hair);
    canvas.drawRect(Rect.fromLTWH(headC.dx - headR, headC.dy - 2, headR * 2, 4), Paint()..color = hair);
    // Face: eyes, smile, bindi.
    final eyeP = Paint()..color = const Color(0xFF3A2A20);
    canvas.drawCircle(Offset(headC.dx - headR * 0.35, headC.dy), 2.4, eyeP);
    canvas.drawCircle(Offset(headC.dx + headR * 0.35, headC.dy), 2.4, eyeP);
    canvas.drawCircle(Offset(headC.dx, headC.dy - headR * 0.45), 2.0, Paint()..color = const Color(0xFFD81B60));
    canvas.drawArc(
      Rect.fromCircle(center: Offset(headC.dx, headC.dy + headR * 0.3), radius: headR * 0.4),
      0.15 * math.pi, 0.7 * math.pi, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = const Color(0xFF8D4A2F),
    );
  }
}
