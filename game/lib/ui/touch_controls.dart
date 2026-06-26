/// On-screen touch controls. Left cluster = move + crouch; right cluster =
/// jump, yoga-jump, meditate (hold to charge aura) and aura-cure (release).
library;

import 'package:flutter/material.dart';

import '../game/shefali_game.dart';

class TouchControls extends StatelessWidget {
  const TouchControls({super.key, required this.game});
  final ShefaliGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Movement cluster.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HoldButton(
                icon: Icons.keyboard_arrow_down,
                label: 'Crouch',
                onDown: () => game.setCrouch(true),
                onUp: () => game.setCrouch(false),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _HoldButton(
                    icon: Icons.arrow_back,
                    onDown: () => game.setHorizontal(-1),
                    onUp: () => game.setHorizontal(0),
                  ),
                  const SizedBox(width: 12),
                  _HoldButton(
                    icon: Icons.arrow_forward,
                    onDown: () => game.setHorizontal(1),
                    onUp: () => game.setHorizontal(0),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Action cluster.
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HoldButton(
                icon: Icons.self_improvement,
                label: 'Meditate',
                color: const Color(0xFF7E57C2),
                onDown: () => game.setMeditate(true),
                onUp: () => game.setMeditate(false),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _TapButton(
                    icon: Icons.auto_awesome,
                    label: 'Cure',
                    color: const Color(0xFF9C6BFF),
                    onTap: game.releaseAura,
                  ),
                  const SizedBox(width: 12),
                  _TapButton(
                    icon: Icons.spa,
                    label: 'Yoga Jump',
                    color: const Color(0xFF26A69A),
                    onTap: game.yogaJump,
                  ),
                  const SizedBox(width: 12),
                  _TapButton(
                    icon: Icons.arrow_upward,
                    label: 'Jump',
                    color: const Color(0xFF42A5F5),
                    onTap: game.jump,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
    this.label,
    this.color = const Color(0xFF3A2A5E),
  });
  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: _ButtonBody(icon: icon, label: label, color: color),
    );
  }
}

class _TapButton extends StatelessWidget {
  const _TapButton({required this.icon, required this.onTap, this.label, required this.color});
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _ButtonBody(icon: icon, label: label, color: color),
    );
  }
}

class _ButtonBody extends StatelessWidget {
  const _ButtonBody({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          if (label != null)
            Text(label!, style: const TextStyle(color: Colors.white, fontSize: 9)),
        ],
      ),
    );
  }
}
