/// Animated main menu. Offline-first: every option works without login. The
/// optional Google sign-in is a non-blocking stub (wired in Phase 3).
library;

import 'package:flutter/material.dart';

import '../logic/difficulty.dart';
import 'app_services.dart';
import 'cutscene.dart';
import 'galleries.dart';
import 'level_select.dart';
import 'menu_background.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _play() {
    final services = AppScope.of(context);
    services.audio.sfx('menu_tap');
    final seen = services.progress.cutscenesSeen.contains('intro');
    if (!seen) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const CutsceneScreen(cutsceneId: 'intro', thenLevelSelect: true),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
    }
  }

  Future<void> _pickDifficulty() async {
    final services = AppScope.of(context);
    final balance = services.config.balance;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Difficulty चुनें'),
        children: [
          for (final id in GameBalance.orderedIds)
            if (balance.profiles.containsKey(id))
              RadioListTile<String>(
                value: id,
                groupValue: services.progress.difficulty,
                title: Text(balance.profiles[id]!.label),
                onChanged: (v) => Navigator.pop(ctx, v),
              ),
        ],
      ),
    );
    if (selected != null) {
      await services.progress.setDifficulty(selected);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 0.97, end: 1.03).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    ),
                    child: Column(
                      children: const [
                        Text('🌿', style: TextStyle(fontSize: 56)),
                        Text(
                          'Prakriti Ki Rakshak',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'SHEFALI',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFCDDC39),
                            letterSpacing: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  _MenuButton(label: '▶  Khelo (Play)', primary: true, onTap: _play),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: '⚙  Difficulty: ${services.difficulty.label}',
                    onTap: _pickDifficulty,
                  ),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: services.soundOn ? '🔊  Sound: On' : '🔇  Sound: Off',
                    onTap: () async {
                      await services.applySoundSetting(!services.soundOn);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: '👗  Character Gallery',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CharacterGalleryScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: '🎬  Story Gallery',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StoryGalleryScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MenuButton(
                    label: '🔐  Google Login (optional)',
                    onTap: () => _showLoginStub(context),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    services.isPlayer2Unlocked
                        ? 'Co-op unlocked: Vaishnav (Player 2) ready!'
                        : 'Co-op (Vaishnav) unlocks after Level 5',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginStub(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Optional Cloud Save'),
        content: const Text(
          'The game is fully playable offline — login is never required.\n\n'
          'Google Sign-In + cloud save arrives in Phase 3.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Theek hai')),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? const Color(0xFF7E57C2) : const Color(0xFF3A2A5E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: primary ? 8 : 2,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
