import 'package:flutter_test/flutter_test.dart';
import 'package:shefali/logic/difficulty.dart';
import 'package:shefali/logic/progress.dart';
import 'package:shefali/logic/unlocks.dart';

void main() {
  group('DifficultyProfile.scaledEnemyCount', () {
    const casual = DifficultyProfile(
      id: 'casual', label: 'Casual', energyDrainPerSecond: 0.5, auraChargePerSecond: 28,
      auraCostPerCure: 25, auraCooldownSeconds: 1, enemyCountMultiplier: 0.6,
      enemySpeedMultiplier: 0.7, puzzlesSkippable: true, levelTimerSeconds: 0,
    );
    test('never drops below 1 when level has enemies', () {
      expect(casual.scaledEnemyCount(1), 1);
      expect(casual.scaledEnemyCount(0), 0);
      expect(casual.scaledEnemyCount(3), inInclusiveRange(1, 3));
    });
  });

  group('GameBalance.fromJson', () {
    test('parses defaults + profiles and falls back safely', () {
      final b = GameBalance.fromJson({
        'defaults': {'maxEnergy': 120, 'player2UnlocksAfterLevel': 5},
        'difficulties': {
          'moderate': {'label': 'Moderate', 'auraCostPerCure': 34},
        },
      });
      expect(b.maxEnergy, 120);
      expect(b.player2UnlocksAfterLevel, 5);
      expect(b.profile('moderate').auraCostPerCure, 34);
      // Unknown id falls back to moderate.
      expect(b.profile('nope').id, 'moderate');
    });
  });

  group('UnlockRules', () {
    const rules = UnlockRules(player2UnlocksAfterLevel: 5);
    test('level 1 always unlocked; later levels gate on previous clear', () {
      expect(rules.isLevelUnlocked(1, highestCleared: 0), isTrue);
      expect(rules.isLevelUnlocked(2, highestCleared: 0), isFalse);
      expect(rules.isLevelUnlocked(2, highestCleared: 1), isTrue);
      expect(rules.isLevelUnlocked(3, highestCleared: 1), isFalse);
    });
    test('player 2 unlocks only after clearing the gate level', () {
      expect(rules.isPlayer2Unlocked(highestCleared: 4), isFalse);
      expect(rules.isPlayer2Unlocked(highestCleared: 5), isTrue);
      expect(rules.isPlayer2Unlocked(highestCleared: 6), isTrue);
    });
  });

  group('PlayerProgress', () {
    test('completeLevel bumps highest, awards badge, tracks best seeds', () async {
      final p = PlayerProgress(MemoryStore());
      expect(p.highestCleared, 0);

      await p.completeLevel(levelId: 'tea_post_1', levelIndex: 1, seedsCollected: 3);
      expect(p.highestCleared, 1);
      expect(p.hasBadge('tea_post_1'), isTrue);
      expect(p.seedsForLevel('tea_post_1'), 3);
      expect(p.totalSeeds, 3);

      // Re-clearing with fewer seeds keeps the best and does not lower totals.
      await p.completeLevel(levelId: 'tea_post_1', levelIndex: 1, seedsCollected: 1);
      expect(p.seedsForLevel('tea_post_1'), 3);
      expect(p.totalSeeds, 3);

      // A better run increases the total by the delta only.
      await p.completeLevel(levelId: 'tea_post_1', levelIndex: 1, seedsCollected: 5);
      expect(p.seedsForLevel('tea_post_1'), 5);
      expect(p.totalSeeds, 5);
    });

    test('difficulty + sound + cutscene persistence', () async {
      final p = PlayerProgress(MemoryStore());
      expect(p.difficulty, 'moderate');
      await p.setDifficulty('hard');
      expect(p.difficulty, 'hard');

      expect(p.soundOn, isTrue);
      await p.setSoundOn(false);
      expect(p.soundOn, isFalse);

      expect(p.cutscenesSeen.contains('intro'), isFalse);
      await p.markCutsceneSeen('intro');
      expect(p.cutscenesSeen.contains('intro'), isTrue);
    });
  });
}
