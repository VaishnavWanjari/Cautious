/// Thin, defensive wrapper over `audioplayers`. Every call is null-safe and
/// wrapped so a MISSING mp3 (an unfilled slot) is silently skipped — this is
/// what lets the owner drop voice/sfx files in gradually with no code changes.
///
/// Path convention: audio_map.json stores package-relative paths like
/// `assets/audio/sfx/jump.mp3`. audioplayers' AssetSource is relative to the
/// `assets/` root, so we strip the leading `assets/` before playing.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../logic/dialogue_model.dart';

class AudioManager {
  AudioManager(this.audioMap);

  final AudioMap audioMap;
  bool soundOn = true;

  // Small round-robin pool so overlapping SFX don't cut each other off.
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _sfxIndex = 0;
  final AudioPlayer _voicePlayer = AudioPlayer();

  static String? _assetPath(String? full) {
    if (full == null || full.trim().isEmpty) return null;
    return full.startsWith('assets/') ? full.substring('assets/'.length) : full;
  }

  Future<void> _safePlay(AudioPlayer player, String? assetRelative, {double volume = 1.0}) async {
    if (!soundOn || assetRelative == null) return;
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(assetRelative));
    } catch (e) {
      // Missing/invalid clip — skip silently. Logged only in debug.
      if (kDebugMode) debugPrint('[audio] skipped "$assetRelative": $e');
    }
  }

  void sfx(String key) {
    final path = _assetPath(audioMap.sfxPath(key));
    if (path == null) return;
    final player = _sfxPool[_sfxIndex];
    _sfxIndex = (_sfxIndex + 1) % _sfxPool.length;
    _safePlay(player, path);
  }

  void voice(String key) {
    if (key.isEmpty) return;
    _safePlay(_voicePlayer, _assetPath(audioMap.voicePath(key)));
  }

  void setSoundOn(bool value) {
    soundOn = value;
    if (!value) {
      for (final p in _sfxPool) {
        p.stop();
      }
      _voicePlayer.stop();
    }
  }

  Future<void> dispose() async {
    for (final p in _sfxPool) {
      await p.dispose();
    }
    await _voicePlayer.dispose();
  }
}
