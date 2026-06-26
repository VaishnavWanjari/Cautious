/// Pure-Dart level model parsed from `assets/config/levels/level_*.json`.
/// Uses its own tiny geometry types so it has zero Flutter/Flame dependencies
/// and can be parsed/validated in plain unit tests.
library;

enum Weather { none, rain, wind }

Weather _parseWeather(String? s) {
  switch (s) {
    case 'rain':
      return Weather.rain;
    case 'wind':
      return Weather.wind;
    default:
      return Weather.none;
  }
}

class LPoint {
  const LPoint(this.x, this.y);
  final double x;
  final double y;
  factory LPoint.fromJson(Map<String, dynamic> j) =>
      LPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

class LRect {
  const LRect(this.x, this.y, this.w, this.h);
  final double x;
  final double y;
  final double w;
  final double h;
  factory LRect.fromJson(Map<String, dynamic> j) => LRect(
        (j['x'] as num).toDouble(),
        (j['y'] as num).toDouble(),
        (j['w'] as num).toDouble(),
        (j['h'] as num).toDouble(),
      );
}

class PlatformDef {
  const PlatformDef({required this.rect, required this.type});
  final LRect rect;
  final String type; // ground | platform
  factory PlatformDef.fromJson(Map<String, dynamic> j) => PlatformDef(
        rect: LRect.fromJson(j),
        type: (j['type'] as String?) ?? 'platform',
      );
}

class EnemyDef {
  const EnemyDef({
    required this.type,
    required this.x,
    required this.y,
    required this.patrol,
    required this.line,
    required this.dropsSeed,
  });
  final String type; // 'litterer' in Phase 1
  final double x;
  final double y;
  final double patrol;
  final String line; // dialogues.json id
  final bool dropsSeed;
  factory EnemyDef.fromJson(Map<String, dynamic> j) => EnemyDef(
        type: (j['type'] as String?) ?? 'litterer',
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        patrol: (j['patrol'] as num?)?.toDouble() ?? 120,
        line: (j['line'] as String?) ?? '',
        dropsSeed: (j['dropsSeed'] as bool?) ?? true,
      );
}

class PickupDef {
  const PickupDef({required this.kind, required this.id, required this.x, required this.y});
  final String kind; // 'seed' | 'food'
  final String id; // food id when kind == 'food'
  final double x;
  final double y;
  factory PickupDef.fromJson(Map<String, dynamic> j) => PickupDef(
        kind: (j['kind'] as String?) ?? 'seed',
        id: (j['id'] as String?) ?? '',
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
      );
}

/// A fully-parsed, validated level.
class LevelModel {
  const LevelModel({
    required this.id,
    required this.index,
    required this.name,
    required this.world,
    required this.width,
    required this.height,
    required this.gravity,
    required this.weather,
    required this.spawn,
    required this.goal,
    required this.dialogueOnStart,
    required this.platforms,
    required this.enemies,
    required this.pickups,
  });

  final String id;
  final int index;
  final String name;
  final String world;
  final double width;
  final double height;
  final double gravity;
  final Weather weather;
  final LPoint spawn;
  final LRect goal;
  final String dialogueOnStart;
  final List<PlatformDef> platforms;
  final List<EnemyDef> enemies;
  final List<PickupDef> pickups;

  int get seedCount => pickups.where((p) => p.kind == 'seed').length;

  factory LevelModel.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? const [])
            .map((e) => f((e as Map).cast<String, dynamic>()))
            .toList();
    return LevelModel(
      id: j['id'] as String,
      index: (j['index'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?) ?? (j['id'] as String),
      world: (j['world'] as String?) ?? 'tea_post',
      width: (j['width'] as num?)?.toDouble() ?? 2400,
      height: (j['height'] as num?)?.toDouble() ?? 720,
      gravity: (j['gravity'] as num?)?.toDouble() ?? 1400,
      weather: _parseWeather(j['weather'] as String?),
      spawn: LPoint.fromJson((j['spawn'] as Map).cast<String, dynamic>()),
      goal: LRect.fromJson((j['goal'] as Map).cast<String, dynamic>()),
      dialogueOnStart: (j['dialogueOnStart'] as String?) ?? '',
      platforms: list('platforms', PlatformDef.fromJson),
      enemies: list('enemies', EnemyDef.fromJson),
      pickups: list('pickups', PickupDef.fromJson),
    );
  }
}
