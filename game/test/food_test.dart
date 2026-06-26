import 'package:flutter_test/flutter_test.dart';
import 'package:shefali/logic/difficulty.dart';
import 'package:shefali/logic/energy_system.dart';
import 'package:shefali/logic/food.dart';

DifficultyProfile _profile() => const DifficultyProfile(
      id: 'test',
      label: 'Test',
      energyDrainPerSecond: 1.0,
      auraChargePerSecond: 20.0,
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
      startEnergy: 50,
      startAura: 10,
      player2UnlocksAfterLevel: 5,
      profiles: {'test': _profile()},
    );

EnergySystem _sys() => EnergySystem(balance: _balance(), difficulty: _profile());

void main() {
  group('FoodItem effects', () {
    test('restoreEnergy adds energy + aura', () {
      final s = _sys();
      const chai = FoodItem(
        id: 'chai', label: 'Chai', effect: FoodEffect.restoreEnergy,
        energy: 25, aura: 5, sprite: '', sfx: 'pickup',
      );
      chai.applyTo(s);
      expect(s.energy, 75);
      expect(s.aura, 15);
    });

    test('fullBoost maxes both regardless of values', () {
      final s = _sys();
      const jam = FoodItem(
        id: 'bread_jam', label: 'Bread Jam', effect: FoodEffect.fullBoost,
        energy: 0, aura: 0, sprite: '', sfx: 'power_up',
      );
      jam.applyTo(s);
      expect(s.energy, 100);
      expect(s.aura, 100);
    });

    test('chill resets cooldown and restores some energy', () {
      final s = _sys();
      s.addAura(60);
      s.tryCure();
      expect(s.cooldownRemaining, greaterThan(0));
      const vada = FoodItem(
        id: 'vada_pav', label: 'Vada Pav', effect: FoodEffect.chill,
        energy: 10, aura: 0, sprite: '', sfx: 'chill',
      );
      vada.applyTo(s);
      expect(s.cooldownRemaining, 0);
      expect(s.energy, 60);
    });

    test('FoodCatalog parses and looks up by id', () {
      final cat = FoodCatalog.fromJson({
        'items': [
          {'id': 'maggi', 'label': 'Maggi', 'effect': 'restoreEnergy', 'energy': 30},
        ],
      });
      expect(cat.byId('maggi')?.energy, 30);
      expect(cat.byId('nope'), isNull);
    });
  });
}
