/// Cross-fades location-based ambient loops (chai-stall buzz at Tea Post, waves
/// at Beach, …). Uses two looping players and ramps their volumes so switching
/// worlds blends rather than cuts. Missing clips are skipped silently.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../logic/dialogue_model.dart';

class AmbientAudioController {
  AmbientAudioController(this.audioMap);

  final AudioMap audioMap;
  bool soundOn = true;

  final AudioPlayer _a = AudioPlayer();
  final AudioPlayer _b = AudioPlayer();
  bool _useA = true;
  String? _currentKey;
  Timer? _fadeTimer;

  static const double _maxVolume = 0.6;
  static const Duration _step = Duration(milliseconds: 60);
  static const int _steps = 14; // ~0.85s fade

  static String? _assetPath(String? full) {
    if (full == null || full.trim().isEmpty) return null;
    return full.startsWith('assets/') ? full.substring('assets/'.length) : full;
  }

  /// Cross-fade to the ambient clip referenced by [ambientKey]. No-op if already
  /// playing it.
  Future<void> crossFadeTo(String ambientKey) async {
    if (ambientKey == _currentKey) return;
    _currentKey = ambientKey;
    final path = _assetPath(audioMap.ambientPath(ambientKey));

    final incoming = _useA ? _b : _a;
    final outgoing = _useA ? _a : _b;
    _useA = !_useA;

    if (soundOn && path != null) {
      try {
        await incoming.setReleaseMode(ReleaseMode.loop);
        await incoming.setVolume(0);
        await incoming.play(AssetSource(path));
      } catch (e) {
        if (kDebugMode) debugPrint('[ambient] skipped "$path": $e');
      }
    }
    _fade(incoming: incoming, outgoing: outgoing);
  }

  void _fade({required AudioPlayer incoming, required AudioPlayer outgoing}) {
    _fadeTimer?.cancel();
    var i = 0;
    _fadeTimer = Timer.periodic(_step, (timer) async {
      i++;
      final t = (i / _steps).clamp(0.0, 1.0);
      try {
        await incoming.setVolume(soundOn ? _maxVolume * t : 0);
        await outgoing.setVolume(soundOn ? _maxVolume * (1 - t) : 0);
      } catch (_) {}
      if (i >= _steps) {
        timer.cancel();
        try {
          await outgoing.stop();
        } catch (_) {}
      }
    });
  }

  void setSoundOn(bool value) {
    soundOn = value;
    if (!value) {
      _a.setVolume(0);
      _b.setVolume(0);
    }
  }

  Future<void> stop() async {
    _fadeTimer?.cancel();
    _currentKey = null;
    try {
      await _a.stop();
      await _b.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _fadeTimer?.cancel();
    await _a.dispose();
    await _b.dispose();
  }
}
