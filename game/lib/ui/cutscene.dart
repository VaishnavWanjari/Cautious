/// Slide-based story cutscene (Hindi). Reads lines with the matching trigger
/// from dialogues.json, plays optional voice clips, marks the cutscene as seen
/// (so it is skipped next time but replayable from the Story Gallery), and can
/// continue into level select.
library;

import 'package:flutter/material.dart';

import '../logic/dialogue_model.dart';
import 'app_services.dart';
import 'level_select.dart';
import 'menu_background.dart';

class CutsceneScreen extends StatefulWidget {
  const CutsceneScreen({
    super.key,
    required this.cutsceneId,
    this.thenLevelSelect = false,
  });

  /// Which trigger group to show. Phase 1 ships 'intro'.
  final String cutsceneId;
  final bool thenLevelSelect;

  @override
  State<CutsceneScreen> createState() => _CutsceneScreenState();
}

class _CutsceneScreenState extends State<CutsceneScreen> {
  List<DialogueLine> _slides = const [];
  int _index = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final services = AppScope.of(context);
    _slides = services.config.dialogues.byTrigger(widget.cutsceneId);
    _playVoiceFor(0);
  }

  void _playVoiceFor(int i) {
    if (i >= 0 && i < _slides.length) {
      AppScope.of(context).audio.voice(_slides[i].voice);
    }
  }

  Future<void> _finish() async {
    final services = AppScope.of(context);
    await services.progress.markCutsceneSeen(widget.cutsceneId);
    if (!mounted) return;
    if (widget.thenLevelSelect) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_index < _slides.length - 1) {
      setState(() => _index++);
      _playVoiceFor(_index);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) {
      return const Scaffold(body: Center(child: Text('No cutscene.')));
    }
    final line = _slides[_index];
    return Scaffold(
      body: MenuBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip ▶', style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    key: ValueKey(_index),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF7E57C2), width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFB39DDB),
                            border: Border.all(color: const Color(0xFFCDDC39), width: 2),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/sprites/shefali/portrait.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Text('🧘', style: TextStyle(fontSize: 30))),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          line.speaker,
                          style: const TextStyle(
                            color: Color(0xFFCDDC39),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          line.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index ? const Color(0xFFCDDC39) : Colors.white24,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7E57C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  onPressed: _next,
                  child: Text(_index < _slides.length - 1 ? 'Aage ▶' : 'Shuru karein 🌿'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
