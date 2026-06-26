/// Pure-Dart data models for the JSON databases (trees, enemies, NPCs, quests,
/// achievements, inventory items). Loaded once into [GameDatabases]. Zero Flame/
/// Flutter imports so everything is unit-testable.
library;

class TreeDef {
  const TreeDef({required this.id, required this.name, required this.sci, required this.growthSeconds, required this.benefit, required this.unlockLevel, required this.sprite});
  final String id, name, sci, benefit, sprite;
  final double growthSeconds;
  final int unlockLevel;
  factory TreeDef.fromJson(Map<String, dynamic> j) => TreeDef(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? j['id'] as String,
        sci: (j['sci'] as String?) ?? '',
        growthSeconds: (j['growthSeconds'] as num?)?.toDouble() ?? 0.7,
        benefit: (j['benefit'] as String?) ?? '',
        unlockLevel: (j['unlockLevel'] as num?)?.toInt() ?? 1,
        sprite: (j['sprite'] as String?) ?? '',
      );
}

class EnemyTypeDef {
  const EnemyTypeDef({required this.id, required this.name, required this.pollution, required this.healPerCure, required this.speed, required this.throwsTrash, required this.behavior, required this.taunts, required this.transformNpc, required this.sprite, required this.curedSprite});
  final String id, name, behavior, transformNpc, sprite, curedSprite;
  final double pollution, healPerCure, speed;
  final bool throwsTrash;
  final List<String> taunts;
  factory EnemyTypeDef.fromJson(Map<String, dynamic> j) => EnemyTypeDef(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? j['id'] as String,
        pollution: (j['pollution'] as num?)?.toDouble() ?? 100,
        healPerCure: (j['healPerCure'] as num?)?.toDouble() ?? 50,
        speed: (j['speed'] as num?)?.toDouble() ?? 70,
        throwsTrash: (j['throwsTrash'] as bool?) ?? true,
        behavior: (j['behavior'] as String?) ?? 'chase',
        taunts: ((j['taunts'] as List?) ?? const []).map((e) => e.toString()).toList(),
        transformNpc: (j['transformNpc'] as String?) ?? 'friend_volunteer',
        sprite: (j['sprite'] as String?) ?? 'litterer',
        curedSprite: (j['curedSprite'] as String?) ?? 'litterer_cured',
      );
}

class NpcDef {
  const NpcDef({required this.id, required this.name, required this.role, required this.lines, required this.gives, required this.emoji, required this.color});
  final String id, name, role, gives, emoji, color;
  final List<String> lines;
  factory NpcDef.fromJson(Map<String, dynamic> j) => NpcDef(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? j['id'] as String,
        role: (j['role'] as String?) ?? '',
        lines: ((j['lines'] as List?) ?? const []).map((e) => e.toString()).toList(),
        gives: (j['gives'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '🙂',
        color: (j['color'] as String?) ?? '#FFCC80',
      );
}

class ObjectiveDef {
  const ObjectiveDef({required this.type, required this.target, required this.labelKey});
  final String type; // heal | plant | talk | collect | reach
  final Object target; // int count or String id
  final String labelKey;
  int get count => target is num ? (target as num).toInt() : 1;
  String get targetId => target is String ? target as String : '';
  factory ObjectiveDef.fromJson(Map<String, dynamic> j) => ObjectiveDef(
        type: (j['type'] as String?) ?? 'reach',
        target: (j['target'] as Object?) ?? 1,
        labelKey: (j['labelKey'] as String?) ?? '',
      );
}

class QuestDef {
  const QuestDef({required this.id, required this.titleKey, required this.world, required this.objectives, required this.rewards});
  final String id, titleKey, world;
  final List<ObjectiveDef> objectives;
  final Map<String, dynamic> rewards;
  factory QuestDef.fromJson(Map<String, dynamic> j) => QuestDef(
        id: j['id'] as String,
        titleKey: (j['titleKey'] as String?) ?? '',
        world: (j['world'] as String?) ?? '',
        objectives: ((j['objectives'] as List?) ?? const [])
            .map((e) => ObjectiveDef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        rewards: (j['rewards'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class AchievementDef {
  const AchievementDef({required this.id, required this.name, required this.desc, required this.icon});
  final String id, name, desc, icon;
  factory AchievementDef.fromJson(Map<String, dynamic> j) => AchievementDef(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? j['id'] as String,
        desc: (j['desc'] as String?) ?? '',
        icon: (j['icon'] as String?) ?? '🏅',
      );
}

class ItemDef {
  const ItemDef({required this.id, required this.tab, required this.name, required this.rarity, required this.icon, required this.desc});
  final String id, tab, name, rarity, icon, desc;
  factory ItemDef.fromJson(Map<String, dynamic> j) => ItemDef(
        id: j['id'] as String,
        tab: (j['tab'] as String?) ?? 'collectible',
        name: (j['name'] as String?) ?? j['id'] as String,
        rarity: (j['rarity'] as String?) ?? 'common',
        icon: (j['icon'] as String?) ?? '❔',
        desc: (j['desc'] as String?) ?? '',
      );
}

/// Container for every loaded database with id lookups.
class GameDatabases {
  GameDatabases({required this.trees, required this.enemyTypes, required this.npcs, required this.quests, required this.achievements, required this.items});
  final Map<String, TreeDef> trees;
  final Map<String, EnemyTypeDef> enemyTypes;
  final Map<String, NpcDef> npcs;
  final Map<String, QuestDef> quests;
  final Map<String, AchievementDef> achievements;
  final Map<String, ItemDef> items;

  TreeDef? tree(String id) => trees[id];
  EnemyTypeDef? enemyType(String id) => enemyTypes[id];
  NpcDef? npc(String id) => npcs[id];
  QuestDef? quest(String id) => quests[id];
  AchievementDef? achievement(String id) => achievements[id];
  ItemDef? item(String id) => items[id];
  Iterable<ItemDef> itemsForTab(String tab) => items.values.where((i) => i.tab == tab);

  static Map<String, T> _byId<T>(List? list, T Function(Map<String, dynamic>) f, String Function(T) idOf) {
    final m = <String, T>{};
    for (final raw in (list ?? const [])) {
      final v = f((raw as Map).cast<String, dynamic>());
      m[idOf(v)] = v;
    }
    return m;
  }

  factory GameDatabases.fromJson({
    required Map<String, dynamic> trees,
    required Map<String, dynamic> enemies,
    required Map<String, dynamic> npcs,
    required Map<String, dynamic> quests,
    required Map<String, dynamic> achievements,
    required Map<String, dynamic> items,
  }) {
    return GameDatabases(
      trees: _byId(trees['trees'] as List?, TreeDef.fromJson, (t) => t.id),
      enemyTypes: _byId(enemies['enemies'] as List?, EnemyTypeDef.fromJson, (e) => e.id),
      npcs: _byId(npcs['npcs'] as List?, NpcDef.fromJson, (n) => n.id),
      quests: _byId(quests['quests'] as List?, QuestDef.fromJson, (q) => q.id),
      achievements: _byId(achievements['achievements'] as List?, AchievementDef.fromJson, (a) => a.id),
      items: _byId(items['items'] as List?, ItemDef.fromJson, (i) => i.id),
    );
  }
}
