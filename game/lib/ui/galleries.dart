/// Character Gallery (Shefali's outfits + cast) and Story Gallery (replay
/// unlocked cutscenes). Phase 1 uses placeholder art; outfit/portrait slots are
/// documented in the README so real sprites drop straight in.
library;

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'cutscene.dart';
import 'menu_background.dart';

class CharacterGalleryScreen extends StatelessWidget {
  const CharacterGalleryScreen({super.key});

  static const _cast = [
    _Char('Shefali', '🧘‍♀️', 'Mechanical engineer • lavender kurti / EPC coverall', Color(0xFFB39DDB)),
    _Char('Vaishnav', '🧔', 'Player 2 (co-op) • unlocks after Level 5', Color(0xFF90CAF9)),
    _Char('Chai Uncle', '🍵', 'Tea Post • sells chai for energy', Color(0xFFFFCC80)),
    _Char('Disha', '😄', 'Comic relief', Color(0xFFF48FB1)),
    _Char('Sanket', '🛠️', 'Colleague & brother', Color(0xFFA5D6A7)),
    _Char('Gullu', '🙂', 'Her brother', Color(0xFFFFAB91)),
    _Char('Monkey', '🐒', 'Recurring comic creature', Color(0xFFBCAAA4)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Character Gallery'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: MenuBackground(
        child: SafeArea(
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            crossAxisCount: 2,
            childAspectRatio: 2.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final c in _cast)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.color, width: 2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 26, backgroundColor: c.color, child: Text(c.emoji, style: const TextStyle(fontSize: 24))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(c.desc, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Char {
  const _Char(this.name, this.emoji, this.desc, this.color);
  final String name;
  final String emoji;
  final String desc;
  final Color color;
}

class StoryGalleryScreen extends StatelessWidget {
  const StoryGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final seen = services.progress.cutscenesSeen;
    // Phase 1 has the 'intro' cutscene; more get listed here as they are added.
    const all = [('intro', 'Shefali ki Shuruaat')];

    return Scaffold(
      appBar: AppBar(title: const Text('Story Gallery'), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: MenuBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            children: [
              for (final entry in all)
                Card(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: ListTile(
                    leading: const Text('🎬', style: TextStyle(fontSize: 28)),
                    title: Text(entry.$2, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      seen.contains(entry.$1) ? 'Tap to replay' : 'Locked — play to unlock',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: Icon(
                      seen.contains(entry.$1) ? Icons.play_circle : Icons.lock,
                      color: seen.contains(entry.$1) ? const Color(0xFFCDDC39) : Colors.white38,
                    ),
                    onTap: seen.contains(entry.$1)
                        ? () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CutsceneScreen(cutsceneId: entry.$1),
                            ))
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
