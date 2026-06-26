/// Pure-Dart food model + the effect each item applies to an [EnergySystem].
library;

import 'energy_system.dart';

enum FoodEffect { restoreEnergy, fullBoost, chill }

FoodEffect _parseEffect(String? s) {
  switch (s) {
    case 'fullBoost':
      return FoodEffect.fullBoost;
    case 'chill':
      return FoodEffect.chill;
    case 'restoreEnergy':
    default:
      return FoodEffect.restoreEnergy;
  }
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.label,
    required this.effect,
    required this.energy,
    required this.aura,
    required this.sprite,
    required this.sfx,
  });

  final String id;
  final String label;
  final FoodEffect effect;
  final double energy;
  final double aura;
  final String sprite;
  final String sfx;

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? (j['id'] as String),
        effect: _parseEffect(j['effect'] as String?),
        energy: (j['energy'] as num?)?.toDouble() ?? 0,
        aura: (j['aura'] as num?)?.toDouble() ?? 0,
        sprite: (j['sprite'] as String?) ?? '',
        sfx: (j['sfx'] as String?) ?? 'pickup',
      );

  /// Apply this item's effect to the energy/aura meters.
  void applyTo(EnergySystem system) {
    switch (effect) {
      case FoodEffect.fullBoost:
        system.fullBoost();
        break;
      case FoodEffect.chill:
        system.resetCooldown();
        system.addEnergy(energy);
        break;
      case FoodEffect.restoreEnergy:
        system.addEnergy(energy);
        system.addAura(aura);
        break;
    }
  }
}

/// Lookup table of food items keyed by id, built from `food.json`.
class FoodCatalog {
  FoodCatalog(this._byId);
  final Map<String, FoodItem> _byId;

  FoodItem? byId(String id) => _byId[id];
  Iterable<FoodItem> get all => _byId.values;

  factory FoodCatalog.fromJson(Map<String, dynamic> j) {
    final list = (j['items'] as List?) ?? const [];
    final map = <String, FoodItem>{};
    for (final raw in list) {
      final item = FoodItem.fromJson((raw as Map).cast<String, dynamic>());
      map[item.id] = item;
    }
    return FoodCatalog(map);
  }
}
