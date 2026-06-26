/// Heads-up display: a Shefali portrait, labeled Energy + Aura meters, the level
/// goal ("Sabko theek karo: x/N"), and score/seed chips. Rebuilds only when the
/// game pushes a new HudState.
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
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7E57C2).withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const _Portrait(),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Meter(icon: '⚡', label: 'Energy', value: hud.energy, color: const Color(0xFFFFB300)),
                      const SizedBox(height: 6),
                      _Meter(
                        icon: '✨',
                        label: 'Aura',
                        value: hud.aura,
                        color: hud.canCure ? const Color(0xFF9C6BFF) : const Color(0xFF5E4B8B),
                        ready: hud.canCure,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hud.goal.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.85),
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
                  _Chip(text: '🏆 ${hud.score}'),
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
      width: 46,
      height: 46,
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
          // Fall back to the painted face if the PNG is absent.
          errorBuilder: (_, __, ___) => CustomPaint(painter: _FacePainter()),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Hair backdrop.
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.4, Paint()..color = const Color(0xFF161616));
    // Face.
    canvas.drawCircle(Offset(w / 2, h * 0.52), w * 0.28, Paint()..color = const Color(0xFFFFD9B0));
    // Fringe.
    canvas.drawArc(Rect.fromCircle(center: Offset(w / 2, h * 0.52), radius: w * 0.29),
        3.14159, 3.14159, true, Paint()..color = const Color(0xFF161616));
    // Eyes + bindi + smile.
    final eye = Paint()..color = const Color(0xFF3A2A20);
    canvas.drawCircle(Offset(w * 0.42, h * 0.52), 1.6, eye);
    canvas.drawCircle(Offset(w * 0.58, h * 0.52), 1.6, eye);
    canvas.drawCircle(Offset(w / 2, h * 0.42), 1.4, Paint()..color = const Color(0xFFD81B60));
    canvas.drawArc(Rect.fromCircle(center: Offset(w / 2, h * 0.58), radius: w * 0.1), 0.2, 2.7, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = const Color(0xFF8D4A2F));
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => false;
}

class _Meter extends StatelessWidget {
  const _Meter({required this.icon, required this.label, required this.value, required this.color, this.ready = false});
  final String icon;
  final String label;
  final double value;
  final Color color;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: 156,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: 0.8), color]),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                ready ? '$label · READY' : label,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
              ),
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
