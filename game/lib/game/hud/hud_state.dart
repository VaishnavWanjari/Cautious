/// Immutable snapshot the HUD widget renders. The game pushes a new value into
/// a ValueNotifier each tick; the Flutter HUD listens. Keeps Flame and widgets
/// decoupled.
library;

class HudState {
  const HudState({
    required this.energy,
    required this.aura,
    required this.score,
    required this.seedsCollected,
    required this.seedsTotal,
    required this.canCure,
    required this.cooldown,
    required this.curedEnemies,
    required this.totalEnemies,
    this.goal = '',
    this.hint = '',
    this.leaves = 5,
    this.maxLeaves = 5,
    this.level = 1,
    this.xpFraction = 0,
    this.coins = 0,
    this.playerName = 'Shefali',
  });

  final double energy; // 0..1 — Green Energy (ability fuel)
  final double aura; // 0..1
  final int score;
  final int seedsCollected;
  final int seedsTotal;
  final bool canCure;
  final double cooldown;
  final int curedEnemies;
  final int totalEnemies;
  final String goal; // e.g. "Theek karo: 1/3"
  final String hint; // transient coaching tip ("" = none)

  // Health + profile (mockup HUD).
  final int leaves; // Green Leaves health (current)
  final int maxLeaves;
  final int level;
  final double xpFraction; // 0..1 progress to next level
  final int coins;
  final String playerName;

  static const empty = HudState(
    energy: 1,
    aura: 0,
    score: 0,
    seedsCollected: 0,
    seedsTotal: 0,
    canCure: false,
    cooldown: 0,
    curedEnemies: 0,
    totalEnemies: 0,
  );
}

/// Result handed back when a level is completed.
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.levelIndex,
    required this.levelName,
    required this.seedsCollected,
    required this.seedsTotal,
    required this.score,
    required this.curedEnemies,
  });

  final String levelId;
  final int levelIndex;
  final String levelName;
  final int seedsCollected;
  final int seedsTotal;
  final int score;
  final int curedEnemies;
}
