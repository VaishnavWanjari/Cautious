/// Pure-Dart unlock rules: which levels are playable and whether Player-2
/// (Vaishnav) co-op is available. No storage/Flutter dependency.
library;

class UnlockRules {
  const UnlockRules({required this.player2UnlocksAfterLevel});

  /// Level (1-based) after which co-op Player-2 becomes available. From
  /// game_balance.json defaults (5 per the brief).
  final int player2UnlocksAfterLevel;

  /// Level [n] (1-based) is unlocked if it is the first level, or the previous
  /// level has been cleared. [highestCleared] is 0 when nothing is cleared yet.
  bool isLevelUnlocked(int n, {required int highestCleared}) {
    if (n <= 1) return true;
    return highestCleared >= n - 1;
  }

  /// Vaishnav unlocks only after Shefali clears the gate level.
  bool isPlayer2Unlocked({required int highestCleared}) =>
      highestCleared >= player2UnlocksAfterLevel;
}
