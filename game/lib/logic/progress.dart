/// Pure-Dart save/progress model — now a full player profile. Persistence is
/// abstracted behind [KeyValueStore] (unit-tested with an in-memory fake; the
/// app injects a shared_preferences-backed impl). Multi-slot: every key is
/// prefixed by the slot id, so several saves coexist. Offline-first and
/// cloud-ready (all keys can be serialized as one blob for sync later).
library;

abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> _m = {};
  @override
  String? getString(String key) => _m[key];
  @override
  Future<void> setString(String key, String value) async => _m[key] = value;
}

/// Static economy/profile defaults loaded from game_balance.json `profile`.
class ProfileDefaults {
  const ProfileDefaults({
    required this.startMaxLeaves,
    required this.startLeaves,
    required this.startGreenEnergyCap,
    required this.xpPerLevel,
    required this.startCoins,
    required this.startGems,
    required this.defaultLanguage,
  });
  final int startMaxLeaves, startLeaves, startGreenEnergyCap, xpPerLevel, startCoins, startGems;
  final String defaultLanguage;

  factory ProfileDefaults.fromJson(Map<String, dynamic> j) => ProfileDefaults(
        startMaxLeaves: (j['startMaxLeaves'] as num?)?.toInt() ?? 5,
        startLeaves: (j['startLeaves'] as num?)?.toInt() ?? 5,
        startGreenEnergyCap: (j['startGreenEnergyCap'] as num?)?.toInt() ?? 100,
        xpPerLevel: (j['xpPerLevel'] as num?)?.toInt() ?? 250,
        startCoins: (j['startCoins'] as num?)?.toInt() ?? 0,
        startGems: (j['startGems'] as num?)?.toInt() ?? 0,
        defaultLanguage: (j['defaultLanguage'] as String?) ?? 'hi',
      );

  static const fallback = ProfileDefaults(
    startMaxLeaves: 5, startLeaves: 5, startGreenEnergyCap: 100,
    xpPerLevel: 250, startCoins: 0, startGems: 0, defaultLanguage: 'hi',
  );
}

class PlayerProgress {
  PlayerProgress(this._store, {this.slot = 's0', this.defaults = ProfileDefaults.fallback});
  final KeyValueStore _store;
  final String slot;
  final ProfileDefaults defaults;

  String _k(String key) => '${slot}_$key';
  String? _get(String key) => _store.getString(_k(key));
  Future<void> _set(String key, String value) => _store.setString(_k(key), value);
  int _int(String key, int dflt) => int.tryParse(_get(key) ?? '') ?? dflt;
  Future<void> _setInt(String key, int v) => _set(key, '$v');

  // --- core progression ---
  int get highestCleared => _int('highestCleared', 0);
  int get totalSeeds => _int('totalSeeds', 0);
  String get difficulty => _get('difficulty') ?? 'moderate';
  bool get soundOn => (_get('soundOn') ?? 'true') == 'true';
  String get language => _get('language') ?? defaults.defaultLanguage;
  String get playerName => _get('playerName') ?? 'Shefali';

  // --- RPG profile ---
  int get xp => _int('xp', 0);
  int get level => 1 + xp ~/ (defaults.xpPerLevel <= 0 ? 250 : defaults.xpPerLevel);
  int get xpIntoLevel => xp % (defaults.xpPerLevel <= 0 ? 250 : defaults.xpPerLevel);
  int get xpPerLevel => defaults.xpPerLevel <= 0 ? 250 : defaults.xpPerLevel;
  int get coins => _int('coins', defaults.startCoins);
  int get gems => _int('gems', defaults.startGems);
  int get naturePoints => _int('naturePoints', 0);
  int get engineeringPoints => _int('engineeringPoints', 0);
  int get compassionPoints => _int('compassionPoints', 0);
  int get maxLeaves => _int('maxLeaves', defaults.startMaxLeaves);
  int get greenEnergyCap => _int('greenEnergyCap', defaults.startGreenEnergyCap);

  Set<String> _set_(String key) {
    final raw = _get(key);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  Set<String> get badges => _set_('badges');
  Set<String> get achievements => _set_('achievements');
  Set<String> get cutscenesSeen => _set_('cutscenesSeen');

  int seedsForLevel(String levelId) => _int('seeds_$levelId', 0);
  bool hasBadge(String levelId) => badges.contains(levelId);
  bool hasAchievement(String id) => achievements.contains(id);

  // --- setters ---
  Future<void> setDifficulty(String id) => _set('difficulty', id);
  Future<void> setSoundOn(bool on) => _set('soundOn', on ? 'true' : 'false');
  Future<void> setLanguage(String lang) => _set('language', lang);

  Future<void> markCutsceneSeen(String id) async {
    final s = cutscenesSeen..add(id);
    await _set('cutscenesSeen', s.join(','));
  }

  Future<void> addXp(int amount) async {
    if (amount <= 0) return;
    await _setInt('xp', xp + amount);
  }

  Future<void> addCoins(int amount) async => _setInt('coins', (coins + amount).clamp(0, 1 << 30));
  Future<void> addGems(int amount) async => _setInt('gems', (gems + amount).clamp(0, 1 << 30));
  Future<void> addNaturePoints(int a) async => _setInt('naturePoints', naturePoints + a);
  Future<void> addEngineeringPoints(int a) async => _setInt('engineeringPoints', engineeringPoints + a);
  Future<void> addCompassionPoints(int a) async => _setInt('compassionPoints', compassionPoints + a);

  Future<void> unlockAchievement(String id) async {
    if (id.isEmpty || achievements.contains(id)) return;
    final s = achievements..add(id);
    await _set('achievements', s.join(','));
  }

  Future<void> awardBadge(String id) async {
    if (id.isEmpty) return;
    final s = badges..add(id);
    await _set('badges', s.join(','));
  }

  /// Apply a quest/level reward map: {xp, greenEnergy, naturePoints, coins, gems,
  /// badge}. Unknown keys ignored.
  Future<void> grantRewards(Map<String, dynamic> r) async {
    await addXp((r['xp'] as num?)?.toInt() ?? 0);
    await addCoins((r['coins'] as num?)?.toInt() ?? 0);
    await addGems((r['gems'] as num?)?.toInt() ?? 0);
    await addNaturePoints((r['naturePoints'] as num?)?.toInt() ?? 0);
    await addEngineeringPoints((r['engineeringPoints'] as num?)?.toInt() ?? 0);
    await addCompassionPoints((r['compassionPoints'] as num?)?.toInt() ?? 0);
    final badge = r['badge'] as String?;
    if (badge != null && badge.isNotEmpty) await awardBadge(badge);
  }

  /// Record a completed level: highest-cleared, appreciation badge, best seeds,
  /// and an XP/coin trickle.
  Future<void> completeLevel({
    required String levelId,
    required int levelIndex,
    required int seedsCollected,
  }) async {
    if (levelIndex > highestCleared) await _setInt('highestCleared', levelIndex);
    await awardBadge(levelId);
    final prevBest = seedsForLevel(levelId);
    if (seedsCollected > prevBest) {
      await _setInt('seeds_$levelId', seedsCollected);
      await _setInt('totalSeeds', totalSeeds + (seedsCollected - prevBest));
    }
  }
}
