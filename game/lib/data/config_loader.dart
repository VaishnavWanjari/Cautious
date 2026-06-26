/// Loads every JSON config from the asset bundle and builds the typed logic
/// models. This is the SINGLE place that knows config file paths, so adding or
/// moving a config only touches this file.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../logic/databases.dart';
import '../logic/difficulty.dart';
import '../logic/dialogue_model.dart';
import '../logic/food.dart';
import '../logic/level_model.dart';
import '../logic/localization.dart';
import '../logic/progress.dart';

/// Immutable bundle of all loaded game content.
class GameConfig {
  GameConfig({
    required this.balance,
    required this.food,
    required this.dialogues,
    required this.audioMap,
    required this.bosses,
    required this.secretReferences,
    required this.worlds,
    required this.levels,
    required this.artMap,
    required this.databases,
    required this.localization,
    required this.profileDefaults,
  });

  final GameBalance balance;
  final FoodCatalog food;
  final DialogueBook dialogues;
  final AudioMap audioMap;
  final List<BossDef> bosses;
  final List<SecretReference> secretReferences;
  final Map<String, WorldDef> worlds;
  final List<LevelModel> levels; // ordered by index

  /// Art slot -> PNG path (see art_map.json + ArtRegistry).
  final Map<String, String> artMap;

  /// Content databases (trees, enemies, NPCs, quests, achievements, items).
  final GameDatabases databases;
  final Localization localization;
  final ProfileDefaults profileDefaults;

  WorldDef? world(String id) => worlds[id];
  LevelModel? levelByIndex(int index) {
    for (final l in levels) {
      if (l.index == index) return l;
    }
    return null;
  }

  /// List of level files to load. Phase 1 ships the three Tea Post levels; add
  /// new entries here (and the file under assets/config/levels/) to grow.
  static const List<String> levelFiles = [
    'assets/config/levels/level_01.json',
    'assets/config/levels/level_02.json',
    'assets/config/levels/level_03.json',
  ];

  static const List<String> worldFiles = [
    'assets/config/world_tea_post.json',
  ];

  static Future<Map<String, dynamic>> _loadObj(String path) async {
    final raw = await rootBundle.loadString(path);
    return (json.decode(raw) as Map).cast<String, dynamic>();
  }

  static Future<dynamic> _loadAny(String path) async {
    final raw = await rootBundle.loadString(path);
    return json.decode(raw);
  }

  /// Load and parse all config. Call once at startup.
  static Future<GameConfig> load() async {
    final balanceJson = await _loadObj('assets/config/game_balance.json');
    final balance = GameBalance.fromJson(balanceJson);
    final profileDefaults = ProfileDefaults.fromJson(
        (balanceJson['profile'] as Map?)?.cast<String, dynamic>() ?? const {});
    final food = FoodCatalog.fromJson(await _loadObj('assets/config/food.json'));
    final dialogues = DialogueBook.fromJson(await _loadObj('assets/config/dialogues.json'));
    final audioMap = AudioMap.fromJson(await _loadObj('assets/config/audio_map.json'));

    final bossesJson = await _loadObj('assets/config/bosses.json');
    final bosses = ((bossesJson['bosses'] as List?) ?? const [])
        .map((e) => BossDef.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final refsRaw = await _loadAny('assets/config/secret_references.json') as List;
    final refs = refsRaw
        .map((e) => SecretReference.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final worlds = <String, WorldDef>{};
    for (final f in worldFiles) {
      final w = WorldDef.fromJson(await _loadObj(f));
      worlds[w.id] = w;
    }

    final levels = <LevelModel>[];
    for (final f in levelFiles) {
      levels.add(LevelModel.fromJson(await _loadObj(f)));
    }
    levels.sort((a, b) => a.index.compareTo(b.index));

    final artRaw = (await _loadObj('assets/config/art_map.json'))['slots'] as Map?;
    final artMap = <String, String>{
      for (final e in (artRaw ?? const {}).entries) e.key.toString(): e.value.toString(),
    };

    final databases = GameDatabases.fromJson(
      trees: await _loadObj('assets/config/db/trees.json'),
      enemies: await _loadObj('assets/config/db/enemies.json'),
      npcs: await _loadObj('assets/config/db/npcs.json'),
      quests: await _loadObj('assets/config/db/quests.json'),
      achievements: await _loadObj('assets/config/db/achievements.json'),
      items: await _loadObj('assets/config/db/items.json'),
    );

    final localization = Localization.fromTables(
      {
        'hi': await _loadObj('assets/config/localization/hi.json'),
        'en': await _loadObj('assets/config/localization/en.json'),
      },
      fallbackLang: 'hi',
      active: profileDefaults.defaultLanguage,
    );

    return GameConfig(
      balance: balance,
      food: food,
      dialogues: dialogues,
      audioMap: audioMap,
      bosses: bosses,
      secretReferences: refs,
      worlds: worlds,
      levels: levels,
      artMap: artMap,
      databases: databases,
      localization: localization,
      profileDefaults: profileDefaults,
    );
  }
}
