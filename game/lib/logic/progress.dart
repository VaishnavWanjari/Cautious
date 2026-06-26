/// Pure-Dart save/progress model. Persistence is abstracted behind [KeyValueStore]
/// so the rules are unit-testable with an in-memory fake; the real app injects a
/// shared_preferences-backed implementation (see lib/data/prefs_store.dart).
library;

/// Minimal synchronous key-value contract the progress model needs.
abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

/// In-memory store for tests and as a safe default before prefs load.
class MemoryStore implements KeyValueStore {
  final Map<String, String> _m = {};
  @override
  String? getString(String key) => _m[key];
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
}

/// Tracks cleared levels, collected seeds, badges, settings and the chosen
/// difficulty. Offline-first: everything lives in the local store; cloud sync
/// (optional Google login) layers on top in Phase 3.
class PlayerProgress {
  PlayerProgress(this._store);
  final KeyValueStore _store;

  static const _kHighestCleared = 'highestCleared';
  static const _kTotalSeeds = 'totalSeeds';
  static const _kDifficulty = 'difficulty';
  static const _kBadges = 'badges'; // comma-separated level ids
  static const _kPerLevelSeedsPrefix = 'seeds_'; // + levelId
  static const _kCutscenesSeen = 'cutscenesSeen';
  static const _kSoundOn = 'soundOn';

  int get highestCleared => int.tryParse(_store.getString(_kHighestCleared) ?? '') ?? 0;
  int get totalSeeds => int.tryParse(_store.getString(_kTotalSeeds) ?? '') ?? 0;
  String get difficulty => _store.getString(_kDifficulty) ?? 'moderate';
  bool get soundOn => (_store.getString(_kSoundOn) ?? 'true') == 'true';

  Set<String> get badges {
    final raw = _store.getString(_kBadges);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Set<String> get cutscenesSeen {
    final raw = _store.getString(_kCutscenesSeen);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  int seedsForLevel(String levelId) =>
      int.tryParse(_store.getString('$_kPerLevelSeedsPrefix$levelId') ?? '') ?? 0;

  bool hasBadge(String levelId) => badges.contains(levelId);

  Future<void> setDifficulty(String id) => _store.setString(_kDifficulty, id);
  Future<void> setSoundOn(bool on) => _store.setString(_kSoundOn, on ? 'true' : 'false');

  Future<void> markCutsceneSeen(String id) async {
    final s = cutscenesSeen..add(id);
    await _store.setString(_kCutscenesSeen, s.join(','));
  }

  /// Record a completed level: bumps highest-cleared, awards the appreciation
  /// badge, and stores the best seed count for that level (keeps the max).
  Future<void> completeLevel({
    required String levelId,
    required int levelIndex,
    required int seedsCollected,
  }) async {
    if (levelIndex > highestCleared) {
      await _store.setString(_kHighestCleared, '$levelIndex');
    }
    final newBadges = badges..add(levelId);
    await _store.setString(_kBadges, newBadges.join(','));

    final prevBest = seedsForLevel(levelId);
    if (seedsCollected > prevBest) {
      final delta = seedsCollected - prevBest;
      await _store.setString('$_kPerLevelSeedsPrefix$levelId', '$seedsCollected');
      await _store.setString(_kTotalSeeds, '${totalSeeds + delta}');
    }
  }
}
