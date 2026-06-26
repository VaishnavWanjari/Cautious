/// Heads-up display: energy + aura meters, score, seed count, cured-enemy
/// progress and an aura-cure readiness pip. Rebuilds only when the game pushes
/// a new HudState.
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
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Meter(label: '⚡', value: hud.energy, color: const Color(0xFFFFB300)),
              const SizedBox(height: 6),
              _Meter(
                label: '🧘',
                value: hud.aura,
                color: hud.canCure ? const Color(0xFF9C6BFF) : const Color(0xFF5E4B8B),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Chip(text: '🌰 ${hud.seedsCollected}/${hud.seedsTotal}'),
                  const SizedBox(width: 8),
                  _Chip(text: '🏆 ${hud.score}'),
                  const SizedBox(width: 8),
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

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Container(
          width: 150,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
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
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }
}
