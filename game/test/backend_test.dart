import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shefali/logic/databases.dart';
import 'package:shefali/logic/localization.dart';
import 'package:shefali/logic/progress.dart';

Map<String, dynamic> _o(String p) =>
    (json.decode(File(p).readAsStringSync()) as Map).cast<String, dynamic>();

void main() {
  group('GameDatabases', () {
    final db = GameDatabases.fromJson(
      trees: _o('assets/config/db/trees.json'),
      enemies: _o('assets/config/db/enemies.json'),
      npcs: _o('assets/config/db/npcs.json'),
      quests: _o('assets/config/db/quests.json'),
      achievements: _o('assets/config/db/achievements.json'),
      items: _o('assets/config/db/items.json'),
    );

    test('loads and looks up by id', () {
      expect(db.tree('neem'), isNotNull);
      expect(db.enemyType('plastic_thrower')!.pollution, greaterThan(0));
      expect(db.npc('tea_uncle')!.gives, 'chai');
      expect(db.quest('q_tea_stall')!.objectives, isNotEmpty);
      expect(db.achievement('first_tree'), isNotNull);
      expect(db.item('chai')!.tab, 'food');
    });

    test('items filter by tab', () {
      expect(db.itemsForTab('food').map((i) => i.id), contains('vada_pav'));
      expect(db.itemsForTab('badge'), isNotEmpty);
    });

    test('quest objective parses target as count or id', () {
      final q = db.quest('q_tea_stall')!;
      final heal = q.objectives.firstWhere((o) => o.type == 'heal');
      expect(heal.count, greaterThanOrEqualTo(1));
      final talk = q.objectives.firstWhere((o) => o.type == 'talk');
      expect(talk.targetId, 'tea_uncle');
    });
  });

  group('Localization', () {
    final loc = Localization.fromTables(
      {'hi': _o('assets/config/localization/hi.json'), 'en': _o('assets/config/localization/en.json')},
      fallbackLang: 'hi',
      active: 'hi',
    );

    test('resolves active language and switches', () {
      expect(loc.t('menu_new_game'), isNotEmpty);
      loc.setLanguage('en');
      expect(loc.t('menu_new_game'), 'New Game');
    });

    test('unknown key falls back to the key', () {
      expect(loc.t('no_such_key'), 'no_such_key');
    });
  });

  group('PlayerProgress profile', () {
    test('xp accrues and levels up by the curve', () async {
      const d = ProfileDefaults(
        startMaxLeaves: 5, startLeaves: 5, startGreenEnergyCap: 100,
        xpPerLevel: 100, startCoins: 0, startGems: 0, defaultLanguage: 'hi',
      );
      final p = PlayerProgress(MemoryStore(), defaults: d);
      expect(p.level, 1);
      await p.addXp(250);
      expect(p.level, 3); // 250 / 100 = 2 -> level 3
      expect(p.xpIntoLevel, 50);
    });

    test('grantRewards applies xp/coins/points/badge', () async {
      final p = PlayerProgress(MemoryStore());
      await p.grantRewards({'xp': 40, 'coins': 100, 'naturePoints': 10, 'badge': 'tree_saver'});
      expect(p.xp, 40);
      expect(p.coins, 100);
      expect(p.naturePoints, 10);
      expect(p.badges, contains('tree_saver'));
    });

    test('achievements unlock once', () async {
      final p = PlayerProgress(MemoryStore());
      await p.unlockAchievement('nature_friend');
      await p.unlockAchievement('nature_friend');
      expect(p.achievements.where((a) => a == 'nature_friend').length, 1);
    });

    test('slots are isolated', () async {
      final store = MemoryStore();
      final s0 = PlayerProgress(store, slot: 's0');
      final s1 = PlayerProgress(store, slot: 's1');
      await s0.addCoins(50);
      expect(s0.coins, 50);
      expect(s1.coins, 0);
    });

    test('language persists', () async {
      final p = PlayerProgress(MemoryStore());
      expect(p.language, 'hi');
      await p.setLanguage('en');
      expect(p.language, 'en');
    });
  });
}
