/// Visual platform/ground block. Collision uses the raw Rect list held by the
/// game (see ShefaliGame.platformRects); this component is render-only.
library;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class PlatformBlock extends PositionComponent {
  PlatformBlock({
    required Vector2 topLeft,
    required Vector2 blockSize,
    required this.isGround,
    required this.groundColor,
  }) {
    position = topLeft.clone();
    size = blockSize.clone();
    anchor = Anchor.topLeft;
  }

  final bool isGround;
  final Color groundColor;

  @override
  void render(Canvas canvas) {
    final base = isGround ? groundColor : const Color(0xFF8D6E63);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Radius.circular(isGround ? 0 : 6),
      ),
      Paint()..color = base,
    );
    // Grass cap on top of solid blocks.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, isGround ? 10 : 6),
      Paint()..color = const Color(0xFF66BB6A),
    );
  }
}

/// The level-exit flag.
class GoalFlag extends PositionComponent {
  GoalFlag({required Vector2 topLeft, required Vector2 flagSize}) {
    position = topLeft.clone();
    size = flagSize.clone();
    anchor = Anchor.topLeft;
  }

  Rect get aabb => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    // Pole.
    canvas.drawRect(Rect.fromLTWH(size.x * 0.45, 0, 6, size.y), Paint()..color = const Color(0xFF5D4037));
    // Flag.
    canvas.drawPath(
      Path()
        ..moveTo(size.x * 0.45, 6)
        ..lineTo(size.x * 0.95, 18)
        ..lineTo(size.x * 0.45, 30)
        ..close(),
      Paint()..color = const Color(0xFF26A69A),
    );
  }
}
