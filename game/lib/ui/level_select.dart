/// Level select. Reads the level list + lock/badge state from services and
/// launches gameplay. Levels unlock sequentially; an appreciation badge shows
/// on every cleared level.
library;

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'gameplay_screen.dart';
import 'menu_background.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final levels = services.config.levels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tea Post — Levels'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: MenuBackground(
        child: SafeArea(
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (final level in levels)
                _LevelTile(
                  index: level.index,
                  name: level.name,
                  unlocked: services.isLevelUnlocked(level.index),
                  hasBadge: services.progress.hasBadge(level.id),
                  bestSeeds: services.progress.seedsForLevel(level.id),
                  totalSeeds: level.seedCount,
                  onTap: () async {
                    if (!services.isLevelUnlocked(level.index)) return;
                    services.audio.sfx('menu_tap');
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GameplayScreen(levelIndex: level.index)),
                    );
                    if (mounted) setState(() {}); // refresh badges/unlocks on return
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.index,
    required this.name,
    required this.unlocked,
    required this.hasBadge,
    required this.bestSeeds,
    required this.totalSeeds,
    required this.onTap,
  });

  final int index;
  final String name;
  final bool unlocked;
  final bool hasBadge;
  final int bestSeeds;
  final int totalSeeds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xFF3A2A5E) : const Color(0xFF241836),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? const Color(0xFF7E57C2) : Colors.white12,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (unlocked)
                    Text('$index',
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold))
                  else
                    const Icon(Icons.lock, color: Colors.white38, size: 28),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  if (unlocked && totalSeeds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('🌰 $bestSeeds/$totalSeeds',
                          style: const TextStyle(color: Color(0xFFCDDC39), fontSize: 11)),
                    ),
                ],
              ),
            ),
            if (hasBadge)
              const Positioned(top: 6, right: 8, child: Text('🏅', style: TextStyle(fontSize: 18))),
          ],
        ),
      ),
    );
  }
}
