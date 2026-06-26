import 'package:flutter_test/flutter_test.dart';
import 'package:shefali/logic/difficulty.dart';
import 'package:shefali/logic/energy_system.dart';

DifficultyProfile _profile() => const DifficultyProfile(
      id: 'test',
      label: 'Test',
      energyDrainPerSecond: 1.0,
      auraChargePerSecond: 20.0,
      auraPassiveRegenPerSecond: 0.0,
      auraCostPerCure: 30.0,
      auraCooldownSeconds: 1.5,
      enemyCountMultiplier: 1.0,
      enemySpeedMultiplier: 1.0,
      puzzlesSkippable: false,
      levelTimerSeconds: 0,
    );

GameBalance _balance() => GameBalance(
      maxEnergy: 100,
      maxAura: 100,
      startEnergy: 80,
      startAura: 0,
      player2UnlocksAfterLevel: 5,
      profiles: {'test': _profile()},
    );

void main() {
  group('EnergySystem', () {
    test('starts at configured energy/aura', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      expect(s.energy, 80);
      expect(s.aura, 0);
      expect(s.energyFraction, closeTo(0.8, 1e-9));
    });

    test('energy drains over time; aura only charges while meditating', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      s.update(1.0, meditating: false);
      expect(s.energy, closeTo(79, 1e-9));
      expect(s.aura, 0);

      s.update(1.0, meditating: true);
      expect(s.energy, closeTo(78, 1e-9));
      expect(s.aura, closeTo(20, 1e-9));
    });

    test('aura and energy are clamped to their maxima', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      s.addAura(1000);
      s.addEnergy(1000);
      expect(s.aura, 100);
      expect(s.energy, 100);
    });

    test('cure requires enough aura, then consumes it and starts cooldown', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      expect(s.canCure, isFalse); // no aura yet
      s.addAura(50);
      expect(s.canCure, isTrue);

      expect(s.tryCure(), isTrue);
      expect(s.aura, closeTo(20, 1e-9));
      expect(s.cooldownRemaining, closeTo(1.5, 1e-9));

      // On cooldown -> cannot cure even with aura.
      s.addAura(50);
      expect(s.canCure, isFalse);
      expect(s.tryCure(), isFalse);

      // Wait out the cooldown.
      s.update(1.5, meditating: false);
      expect(s.canCure, isTrue);
    });

    test('vada-pav chill resets the cooldown immediately', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      s.addAura(60);
      s.tryCure();
      expect(s.cooldownRemaining, greaterThan(0));
      s.resetCooldown();
      expect(s.cooldownRemaining, 0);
    });

    test('spendEnergy fails when insufficient', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      expect(s.spendEnergy(10), isTrue);
      expect(s.spendEnergy(1000), isFalse);
      expect(s.energy, 70);
    });

    test('fullBoost maxes both meters', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      s.fullBoost();
      expect(s.energy, 100);
      expect(s.aura, 100);
    });

    test('isExhausted true at zero energy', () {
      final s = EnergySystem(balance: _balance(), difficulty: _profile());
      s.addEnergy(-1000);
      expect(s.isExhausted, isTrue);
    });
  });
}
