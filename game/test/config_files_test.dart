// Loads the REAL config JSON from disk (CWD is the package root under
// `flutter test`) and asserts every file parses into its model AND that the
// cross-references between configs are intact. This is the automated backbone
// of the project's QC: a dangling enemy line, a food id with no catalog entry,
// or a dialogue voice key missing from audio_map.json fails the build.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shefali/logic/difficulty.dart';
import 'package:shefali/logic/dialogue_model.dart';
import 'package:shefali/logic/food.dart';
import 'package:shefali/logic/level_model.dart';

Map<String, dynamic> _obj(String path) =>
    (json.decode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

List<dynamic> _arr(String path) => json.decode(File(path).readAsStringSync()) as List;

const _levelFiles = [
  'assets/config/levels/level_01.json',
  'assets/config/levels/level_02.json',
  'assets/config/levels/level_03.json',
];

void main() {
  final balance = GameBalance.fromJson(_obj('assets/config/game_balance.json'));
  final food = FoodCatalog.fromJson(_obj('assets/config/food.json'));
  final dialogues = DialogueBook.fromJson(_obj('assets/config/dialogues.json'));
  final audioMap = AudioMap.fromJson(_obj('assets/config/audio_map.json'));
  final world = WorldDef.fromJson(_obj('assets/config/world_tea_post.json'));
  final levels = _levelFiles.map((f) => LevelModel.fromJson(_obj(f))).toList();

  test('game_balance has all three difficulties', () {
    for (final id in GameBalance.orderedIds) {
      expect(balance.profiles.containsKey(id), isTrue, reason: 'missing difficulty "$id"');
    }
    expect(balance.player2UnlocksAfterLevel, 5);
  });

  test('bosses.json parses; one every 5 levels', () {
    final bosses = (_obj('assets/config/bosses.json')['bosses'] as List)
        .map((e) => BossDef.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    expect(bosses, isNotEmpty);
    for (final b in bosses) {
      expect(b.level % 5, 0, reason: 'boss ${b.id} not on a multiple of 5');
    }
  });

  test('art_map.json has slot->path string entries', () {
    final slots = (_obj('assets/config/art_map.json')['slots'] as Map).cast<String, dynamic>();
    expect(slots, isNotEmpty);
    for (final e in slots.entries) {
      expect(e.value, isA<String>(), reason: 'art slot ${e.key} must map to a path string');
      expect((e.value as String).trim(), isNotEmpty);
    }
  });

  test('secret_references.json parses', () {
    final refs = _arr('assets/config/secret_references.json')
        .map((e) => SecretReference.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    expect(refs, isNotEmpty);
  });

  test('every dialogue voice key resolves in audio_map', () {
    for (final line in dialogues.all) {
      if (line.voice.isEmpty) continue;
      expect(audioMap.voicePath(line.voice), isNotNull,
          reason: 'dialogue "${line.id}" voice "${line.voice}" not in audio_map.voice');
    }
  });

  test('world ambient key resolves in audio_map', () {
    expect(audioMap.ambientPath(world.ambient), isNotNull,
        reason: 'world ambient "${world.ambient}" not in audio_map.ambient');
  });

  test('every food sfx key resolves in audio_map', () {
    for (final item in food.all) {
      expect(audioMap.sfxPath(item.sfx), isNotNull,
          reason: 'food "${item.id}" sfx "${item.sfx}" not in audio_map.sfx');
    }
  });

  group('levels are internally consistent', () {
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      test('${level.id} cross-references + bounds', () {
        // Spawn + goal inside the level bounds.
        expect(level.spawn.x, inInclusiveRange(0, level.width));
        expect(level.spawn.y, inInclusiveRange(0, level.height));
        expect(level.goal.x + level.goal.w, lessThanOrEqualTo(level.width + 1));

        // Enemy dialogue lines exist.
        for (final e in level.enemies) {
          expect(e.type, 'litterer', reason: 'unimplemented enemy type in ${level.id}');
          expect(dialogues.byId(e.line), isNotNull,
              reason: 'enemy line "${e.line}" missing in dialogues.json');
        }
        // Food pickups reference real catalog items.
        for (final p in level.pickups) {
          if (p.kind == 'food') {
            expect(food.byId(p.id), isNotNull,
                reason: 'food pickup "${p.id}" not in food.json');
          }
        }
        // Start dialogue exists when set.
        if (level.dialogueOnStart.isNotEmpty) {
          expect(dialogues.byId(level.dialogueOnStart), isNotNull);
        }
      });
    }

    test('level indexes are unique and sequential from 1', () {
      final indexes = levels.map((l) => l.index).toList()..sort();
      expect(indexes, [for (var i = 1; i <= levels.length; i++) i]);
    });
  });
}
