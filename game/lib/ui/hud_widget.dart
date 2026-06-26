/// Mockup-style HUD: an avatar card (portrait + name + level + XP bar), the
/// Green-Leaf health row, Green Energy + Aura meters, a quest/goal pill and
/// score/seed/coin chips. Rebuilds only when the game pushes a new HudState.
library;

import 'package:flutter/material.dart';

import '../game/hud/hud_state.dart';

class HudWidget extends StatelessWidget {
  const HudWidget({super.key, required this.notifier});
  final ValueNotifier<HudState> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HudState>(
      valueListenable: notifier,
      builder: (context, hud, _) {
        return Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.6), Colors.black.withValues(alpha: 0.32)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF7E57C2).withValues(alpha: 0.65), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      const _Portrait(),
                      Positioned(
                        bottom: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A2E83),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCDDC39), width: 1),
                          ),
                          child: Text('Lv ${hud.level}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hud.playerName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      // XP bar.
                      _Bar(width: 150, height: 6, value: hud.xpFraction, color: const Color(0xFF4FC3F7)),
                      const SizedBox(height: 5),
                      _Leaves(leaves: hud.leaves, max: hud.maxLeaves),
                      const SizedBox(height: 5),
                      _Meter(icon: '🌿', value: hud.energy, color: const Color(0xFF66BB6A)),
                      const SizedBox(height: 4),
                      _Meter(
                        icon: '✨',
                        value: hud.aura,
                        color: hud.canCure ? const Color(0xFF9C6BFF) : const Color(0xFF5E4B8B),
                        ready: hud.canCure,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hud.goal.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('🎯 ${hud.goal}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Chip(text: '🌰 ${hud.seedsCollected}/${hud.seedsTotal}'),
                  const SizedBox(width: 6),
                  _Chip(text: '🪙 ${hud.coins}'),
                  const SizedBox(width: 6),
                  _Chip(text: '💚 ${hud.curedEnemies}/${hud.totalEnemies}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF7E57C2), Color(0xFF4A2E83)]),
        border: Border.all(color: const Color(0xFFCDDC39), width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/sprites/shefali/portrait.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => CustomPaint(painter: _FacePainter()),
        ),
      ),
    );
  }
}

class _Leaves extends StatelessWidget {
  const _Leaves({required this.leaves, required this.max});
  final int leaves;
  final int max;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text('🍃',
                style: TextStyle(
                  fontSize: 14,
                  color: i < leaves ? null : Colors.white24,
                )),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.value, required this.color});
  final double width, height, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: Colors.white24),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.icon, required this.value, required this.color, this.ready = false});
  final String icon;
  final double value;
  final Color color;
  final bool ready;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            _Bar(width: 150, height: 14, value: value, color: color),
            if (ready)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('READY',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _FacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.4, Paint()..color = const Color(0xFF161616));
    canvas.drawCircle(Offset(w / 2, h * 0.52), w * 0.28, Paint()..color = const Color(0xFFFFD9B0));
    final eye = Paint()..color = const Color(0xFF3A2A20);
    canvas.drawCircle(Offset(w * 0.42, h * 0.52), 1.6, eye);
    canvas.drawCircle(Offset(w * 0.58, h * 0.52), 1.6, eye);
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => false;
}
