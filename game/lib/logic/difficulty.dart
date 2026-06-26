/// Pure-Dart difficulty model. No Flame/Flutter imports so it is unit-testable.
///
/// Loaded from `assets/config/game_balance.json`. See [GameBalance.fromJson].
library;

/// One difficulty profile (Casual / Moderate / Hard).
class DifficultyProfile {
  const DifficultyProfile({
    required this.id,
    required this.label,
    required this.energyDrainPerSecond,
    required this.auraChargePerSecond,
    required this.auraCostPerCure,
    required this.auraCooldownSeconds,
    required this.enemyCountMultiplier,
    required this.enemySpeedMultiplier,
    required this.puzzlesSkippable,
    required this.levelTimerSeconds,
  });

  final String id;
  final String label;
  final double energyDrainPerSecond;
  final double auraChargePerSecond;
  final double auraCostPerCure;
  final double auraCooldownSeconds;
  final double enemyCountMultiplier;
  final double enemySpeedMultiplier;
  final bool puzzlesSkippable;
  final int levelTimerSeconds;

  factory DifficultyProfile.fromJson(String id, Map<String, dynamic> j) {
    double d(String k, double fallback) => (j[k] as num?)?.toDouble() ?? fallback;
    return DifficultyProfile(
      id: id,
      label: (j['label'] as String?) ?? id,
      energyDrainPerSecond: d('energyDrainPerSecond', 1.0),
      auraChargePerSecond: d('auraChargePerSecond', 20.0),
      auraCostPerCure: d('auraCostPerCure', 34.0),
      auraCooldownSeconds: d('auraCooldownSeconds', 1.5),
      enemyCountMultiplier: d('enemyCountMultiplier', 1.0),
      enemySpeedMultiplier: d('enemySpeedMultiplier', 1.0),
      puzzlesSkippable: (j['puzzlesSkippable'] as bool?) ?? false,
      levelTimerSeconds: (j['levelTimerSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  /// How many enemies to actually spawn from a level's `enemies` list for this
  /// difficulty. Never drops below 1 if the level defines at least one.
  int scaledEnemyCount(int defined) {
    if (defined <= 0) return 0;
    final scaled = (defined * enemyCountMultiplier).round();
    return scaled.clamp(1, defined);
  }
}

/// Global balance config: defaults + the three difficulty profiles.
class GameBalance {
  const GameBalance({
    required this.maxEnergy,
    required this.maxAura,
    required this.startEnergy,
    required this.startAura,
    required this.player2UnlocksAfterLevel,
    required this.profiles,
  });

  final double maxEnergy;
  final double maxAura;
  final double startEnergy;
  final double startAura;
  final int player2UnlocksAfterLevel;
  final Map<String, DifficultyProfile> profiles;

  static const List<String> orderedIds = ['casual', 'moderate', 'hard'];

  DifficultyProfile profile(String id) =>
      profiles[id] ?? profiles['moderate'] ?? profiles.values.first;

  factory GameBalance.fromJson(Map<String, dynamic> j) {
    final defaults = (j['defaults'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawDiffs = (j['difficulties'] as Map?)?.cast<String, dynamic>() ?? const {};
    final profiles = <String, DifficultyProfile>{};
    rawDiffs.forEach((id, value) {
      profiles[id] = DifficultyProfile.fromJson(id, (value as Map).cast<String, dynamic>());
    });
    double d(String k, double fallback) => (defaults[k] as num?)?.toDouble() ?? fallback;
    return GameBalance(
      maxEnergy: d('maxEnergy', 100),
      maxAura: d('maxAura', 100),
      startEnergy: d('startEnergy', 80),
      startAura: d('startAura', 0),
      player2UnlocksAfterLevel: (defaults['player2UnlocksAfterLevel'] as num?)?.toInt() ?? 5,
      profiles: profiles,
    );
  }
}
