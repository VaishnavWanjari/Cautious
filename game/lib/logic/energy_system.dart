/// Pure-Dart energy + aura model. The single source of truth for both meters;
/// the Flame layer only feeds it `dt` and reads its values. Fully unit-tested.
library;

import 'difficulty.dart';

/// Tracks Shefali's energy (fuels powers) and aura (built by meditation, spent
/// on cures). All mutation goes through methods so rules stay testable.
class EnergySystem {
  EnergySystem({required this.balance, required this.difficulty})
      : _energy = balance.startEnergy,
        _aura = balance.startAura;

  final GameBalance balance;
  DifficultyProfile difficulty;

  double _energy;
  double _aura;
  double _cooldownRemaining = 0;

  double get energy => _energy;
  double get aura => _aura;
  double get maxEnergy => balance.maxEnergy;
  double get maxAura => balance.maxAura;
  double get energyFraction => maxEnergy == 0 ? 0 : (_energy / maxEnergy).clamp(0.0, 1.0);
  double get auraFraction => maxAura == 0 ? 0 : (_aura / maxAura).clamp(0.0, 1.0);
  double get cooldownRemaining => _cooldownRemaining;

  bool get isExhausted => _energy <= 0;
  bool get canCure => _cooldownRemaining <= 0 && _aura >= difficulty.auraCostPerCure;

  /// Advance time. [meditating] fills aura (only while there is energy to spend
  /// on staying focused). Energy always drains slowly to encourage eating.
  void update(double dt, {required bool meditating}) {
    if (dt <= 0) return;
    if (_cooldownRemaining > 0) {
      _cooldownRemaining = (_cooldownRemaining - dt).clamp(0.0, double.infinity);
    }
    // Passive energy drain.
    _energy = (_energy - difficulty.energyDrainPerSecond * dt).clamp(0.0, maxEnergy);
    // Meditation charges aura while energy remains.
    if (meditating && _energy > 0) {
      _aura = (_aura + difficulty.auraChargePerSecond * dt).clamp(0.0, maxAura);
    }
  }

  /// Attempt to release an aura cure. Returns true if it fired (enough aura and
  /// off cooldown), consuming aura and starting the cooldown.
  bool tryCure() {
    if (!canCure) return false;
    _aura = (_aura - difficulty.auraCostPerCure).clamp(0.0, maxAura);
    _cooldownRemaining = difficulty.auraCooldownSeconds;
    return true;
  }

  /// Spend energy for a power (e.g. yoga jump). Returns false if insufficient.
  bool spendEnergy(double amount) {
    if (amount <= 0) return true;
    if (_energy < amount) return false;
    _energy = (_energy - amount).clamp(0.0, maxEnergy);
    return true;
  }

  void addEnergy(double amount) =>
      _energy = (_energy + amount).clamp(0.0, maxEnergy);

  void addAura(double amount) => _aura = (_aura + amount).clamp(0.0, maxAura);

  void fullBoost() {
    _energy = maxEnergy;
    _aura = maxAura;
  }

  /// "Chill" effect (vada pav): clears the aura cooldown immediately.
  void resetCooldown() => _cooldownRemaining = 0;
}
