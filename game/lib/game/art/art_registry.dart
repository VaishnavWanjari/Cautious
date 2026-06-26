/// Optional sprite layer. For each art "slot" (e.g. shefali_idle, chai,
/// magaj_seed, bg_tea_post) it tries to load a PNG declared in art_map.json. If
/// the file is present the component draws the sprite; if not, the component
/// falls back to its hand-drawn vector art. This is what lets the owner reach
/// the illustrated reference look by dropping PNGs in — with no code change.
library;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ArtRegistry {
  ArtRegistry(this._slotToPath);

  /// slot key -> package-relative asset path (e.g. assets/sprites/shefali/idle.png).
  final Map<String, String> _slotToPath;

  // prefix '' so we can pass full package-relative paths (Flame's default
  // Images prefix is assets/images/, which we don't want here).
  final Images _images = Images(prefix: '');
  final Map<String, Sprite> _sprites = {};

  /// Try to load every mapped slot. Missing/invalid files are skipped silently
  /// so the game runs on pure vector art until real PNGs are supplied.
  Future<void> preload() async {
    for (final entry in _slotToPath.entries) {
      final path = entry.value.trim();
      if (path.isEmpty) continue;
      try {
        final image = await _images.load(path);
        _sprites[entry.key] = Sprite(image);
      } catch (e) {
        if (kDebugMode) debugPrint('[art] slot "${entry.key}" not loaded ($path): vector fallback');
      }
    }
  }

  Sprite? sprite(String slot) => _sprites[slot];
  bool has(String slot) => _sprites.containsKey(slot);

  /// Convenience: draw the slot's sprite stretched to [size] at the component
  /// origin, returning true if it drew (so callers can else-draw vector art).
  bool draw(Canvas canvas, String slot, Vector2 size) {
    final s = _sprites[slot];
    if (s == null) return false;
    s.render(canvas, size: size);
    return true;
  }
}
