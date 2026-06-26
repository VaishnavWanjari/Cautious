/// Hosts the Flame game canvas with the HUD, touch controls, weather overlay
/// and the dialogue / pause / victory / game-over overlays. Owns the game's
/// lifecycle and persists progress on a win.
library;

import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/hud/hud_state.dart';
import '../game/shefali_game.dart';
import '../logic/dialogue_model.dart';
import '../logic/level_model.dart';
import 'app_services.dart';
import 'hud_widget.dart';
import 'touch_controls.dart';
import 'weather_overlay.dart';

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.levelIndex});
  final int levelIndex;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  AppServices? _services;
  ShefaliGame? _game;
  LevelModel? _level;

  DialogueLine? _dialogue;
  Timer? _dialogueTimer;
  LevelResult? _result;
  bool _gameOver = false;
  bool _paused = false;
  bool _built = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_built) return;
    _built = true;
    _services = AppScope.of(context);
    _build();
  }

  void _build() {
    final services = _services!;
    final level = services.config.levelByIndex(widget.levelIndex);
    if (level == null) return;
    _level = level;
    _game = ShefaliGame(
      config: services.config,
      level: level,
      difficulty: services.difficulty,
      audio: services.audio,
      ambient: services.ambient,
      hapticsOn: services.hapticsOn,
      onDialogue: _showDialogue,
      onLevelComplete: _onLevelComplete,
      onGameOver: _onGameOver,
    );
  }

  void _showDialogue(DialogueLine line) {
    setState(() => _dialogue = line);
    _dialogueTimer?.cancel();
    _dialogueTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _dialogue = null);
    });
  }

  Future<void> _onLevelComplete(LevelResult result) async {
    _game?.pauseEngine();
    await _services!.progress.completeLevel(
      levelId: result.levelId,
      levelIndex: result.levelIndex,
      seedsCollected: result.seedsCollected,
    );
    if (mounted) setState(() => _result = result);
  }

  void _onGameOver() {
    _game?.pauseEngine();
    if (mounted) setState(() => _gameOver = true);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _game?.pauseEngine();
    } else {
      _game?.resumeEngine();
    }
  }

  void _restart() {
    setState(() {
      _result = null;
      _gameOver = false;
      _paused = false;
      _dialogue = null;
      _built = false;
    });
    // Rebuild a fresh game next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _built = true;
        _build();
      });
    });
  }

  void _goToLevel(int index) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameplayScreen(levelIndex: index)),
    );
  }

  @override
  void dispose() {
    _dialogueTimer?.cancel();
    _services?.ambient.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null || _level == null) {
      return const Scaffold(body: Center(child: Text('Level not found.')));
    }
    final nextIndex = widget.levelIndex + 1;
    final hasNext = _services!.config.levelByIndex(nextIndex) != null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(key: ObjectKey(game), game: game)),
          Positioned.fill(child: WeatherOverlay(weather: _level!.weather)),

          // HUD (top-left) + pause (top-right).
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: HudWidget(notifier: game.hud),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.pause),
                  onPressed: _togglePause,
                ),
              ),
            ),
          ),

          // Touch controls (hidden while an overlay is up).
          if (_result == null && !_gameOver && !_paused)
            SafeArea(
              child: Align(alignment: Alignment.bottomCenter, child: TouchControls(game: game)),
            ),

          // Transient dialogue bubble.
          if (_dialogue != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: _DialogueBubble(line: _dialogue!),
              ),
            ),

          // Coaching hint banner (driven by HUD state).
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<HudState>(
                valueListenable: game.hud,
                builder: (context, hud, _) {
                  if (hud.hint.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A2E83).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCDDC39), width: 1.5),
                    ),
                    child: Text(hud.hint,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
          ),

          if (_paused) _PauseOverlay(onResume: _togglePause, onMenu: () => Navigator.of(context).pop()),
          if (_result != null)
            _VictoryOverlay(
              result: _result!,
              hasNext: hasNext,
              onNext: hasNext ? () => _goToLevel(nextIndex) : null,
              onReplay: _restart,
              onMenu: () => Navigator.of(context).pop(),
            ),
          if (_gameOver)
            _GameOverOverlay(onRetry: _restart, onMenu: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

class _DialogueBubble extends StatelessWidget {
  const _DialogueBubble({required this.line});
  final DialogueLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 90),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7E57C2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A2E83),
              border: Border.all(color: const Color(0xFFCDDC39), width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset(
                line.portrait,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    line.speaker.isNotEmpty ? line.speaker[0] : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.speaker,
                    style: const TextStyle(color: Color(0xFFCDDC39), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(line.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(child: child),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onMenu});
  final VoidCallback onResume;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Paused', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _OverlayButton(label: 'Resume', onTap: onResume, primary: true),
          const SizedBox(height: 10),
          _OverlayButton(label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay({
    required this.result,
    required this.hasNext,
    required this.onNext,
    required this.onReplay,
    required this.onMenu,
  });
  final LevelResult result;
  final bool hasNext;
  final VoidCallback? onNext;
  final VoidCallback onReplay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A2E83),
              border: Border.all(color: const Color(0xFFCDDC39), width: 3),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/sprites/shefali/happy.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const Center(child: Text('🏅', style: TextStyle(fontSize: 48))),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Shabaash! 🏅', style: TextStyle(color: Color(0xFFCDDC39), fontSize: 32, fontWeight: FontWeight.bold)),
          Text(result.levelName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Appreciation Badge earned', style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 4),
          Text('🌰 ${result.seedsCollected}/${result.seedsTotal}   💚 ${result.curedEnemies}   🏆 ${result.score}',
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 20),
          if (hasNext && onNext != null) _OverlayButton(label: 'Next Level ▶', onTap: onNext!, primary: true),
          const SizedBox(height: 10),
          _OverlayButton(label: 'Replay', onTap: onReplay),
          const SizedBox(height: 10),
          _OverlayButton(label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.onRetry, required this.onMenu});
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😴', style: TextStyle(fontSize: 64)),
          const Text('Energy khatam!',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Chai peeke phir try karein.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          _OverlayButton(label: 'Retry', onTap: onRetry, primary: true),
          const SizedBox(height: 10),
          _OverlayButton(label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? const Color(0xFF7E57C2) : const Color(0xFF3A2A5E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
