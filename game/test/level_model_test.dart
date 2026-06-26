import 'package:flutter_test/flutter_test.dart';
import 'package:shefali/logic/level_model.dart';

void main() {
  test('LevelModel parses platforms, enemies, pickups and computes seed count', () {
    final level = LevelModel.fromJson({
      'id': 'demo',
      'index': 1,
      'name': 'Demo',
      'world': 'tea_post',
      'width': 2000,
      'height': 720,
      'gravity': 1400,
      'weather': 'rain',
      'spawn': {'x': 100, 'y': 500},
      'goal': {'x': 1900, 'y': 470, 'w': 80, 'h': 150},
      'dialogueOnStart': 'shefali_cure_all',
      'platforms': [
        {'x': 0, 'y': 640, 'w': 2000, 'h': 80, 'type': 'ground'},
        {'x': 300, 'y': 520, 'w': 150, 'h': 24, 'type': 'platform'},
      ],
      'enemies': [
        {'type': 'litterer', 'x': 700, 'y': 580, 'patrol': 150, 'line': 'enemy_plastic'},
      ],
      'pickups': [
        {'kind': 'seed', 'x': 320, 'y': 470},
        {'kind': 'seed', 'x': 500, 'y': 470},
        {'kind': 'food', 'id': 'chai', 'x': 360, 'y': 470},
      ],
    });

    expect(level.weather, Weather.rain);
    expect(level.platforms.length, 2);
    expect(level.platforms.first.type, 'ground');
    expect(level.enemies.single.line, 'enemy_plastic');
    expect(level.enemies.single.dropsSeed, isTrue); // defaulted
    expect(level.seedCount, 2);
  });

  test('unknown weather defaults to none', () {
    final level = LevelModel.fromJson({
      'id': 'd', 'index': 1, 'spawn': {'x': 0, 'y': 0}, 'goal': {'x': 0, 'y': 0, 'w': 1, 'h': 1},
    });
    expect(level.weather, Weather.none);
  });
}
