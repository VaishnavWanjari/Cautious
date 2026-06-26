/// App-wide services + state, created once at boot and shared via an
/// InheritedWidget. (Kept deliberately lightweight; can be swapped for Riverpod
/// or Bloc in a later phase without touching call sites much.)
library;

import 'package:flutter/widgets.dart';

import '../data/config_loader.dart';
import '../game/audio/ambient_controller.dart';
import '../game/audio/audio_manager.dart';
import '../logic/difficulty.dart';
import '../logic/progress.dart';
import '../logic/unlocks.dart';

class AppServices {
  AppServices({
    required this.config,
    required this.progress,
    required this.audio,
    required this.ambient,
  }) : unlocks = UnlockRules(player2UnlocksAfterLevel: config.balance.player2UnlocksAfterLevel);

  final GameConfig config;
  final PlayerProgress progress;
  final AudioManager audio;
  final AmbientAudioController ambient;
  final UnlockRules unlocks;

  bool get soundOn => progress.soundOn;
  bool get hapticsOn => progress.soundOn; // Phase 1: tied to the sound toggle.

  DifficultyProfile get difficulty => config.balance.profile(progress.difficulty);

  bool get isPlayer2Unlocked =>
      unlocks.isPlayer2Unlocked(highestCleared: progress.highestCleared);

  bool isLevelUnlocked(int index) =>
      unlocks.isLevelUnlocked(index, highestCleared: progress.highestCleared);

  Future<void> applySoundSetting(bool on) async {
    await progress.setSoundOn(on);
    audio.setSoundOn(on);
    ambient.setSoundOn(on);
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
