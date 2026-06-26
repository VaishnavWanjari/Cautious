/// The root Flame game. Builds a level from a parsed [LevelModel], runs the
/// AABB platformer, drives the pure [EnergySystem], and reports HUD state /
/// dialogue / completion back to the Flutter layer via callbacks + a notifier.
library;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/config_loader.dart';
import '../logic/difficulty.dart';
import '../logic/dialogue_model.dart';
import '../logic/energy_system.dart';
import '../logic/level_model.dart';
import 'art/art_registry.dart';
import 'audio/ambient_controller.dart';
import 'audio/audio_manager.dart';
import 'effects/effects.dart';
import 'enemies/litterer.dart';
import 'hud/hud_state.dart';
import 'pickups/pickups.dart';
import 'platforms/platform_block.dart';
import 'player/shefali.dart';
import 'world/tree.dart';

class ShefaliGame extends FlameGame {
  ShefaliGame({
    required this.config,
    required this.level,
    required this.difficulty,
    required this.audio,
    required this.ambient,
    required this.hapticsOn,
    required this.onDialogue,
    required this.onLevelComplete,
    required this.onGameOver,
    this.profileLevel = 1,
    this.profileXpFraction = 0,
    this.profileCoins = 0,
    this.playerName = 'Shefali',
  })  : energy = EnergySystem(balance: config.balance, difficulty: difficulty),
        super();

  final GameConfig config;
  final LevelModel level;
  final DifficultyProfile difficulty;
  final EnergySystem energy;
  final AudioManager audio;
  final AmbientAudioController ambient;
  final bool hapticsOn;

  // Persistent profile snapshot for the HUD (static during a level).
  final int profileLevel;
  final double profileXpFraction;
  final int profileCoins;
  final String playerName;

  /// Fired when an enemy speaks / on level-start line. UI shows a dialogue bubble.
  final void Function(DialogueLine line) onDialogue;
  final void Function(LevelResult result) onLevelComplete;
  final VoidCallback onGameOver;

  final ValueNotifier<HudState> hud = ValueNotifier(HudState.empty);

  late final Shefali player;
  late final EffectsManager effects;
  late final ArtRegistry art;

  final List<Rect> platformRects = [];
  final List<Litterer> enemies = [];
  final List<SeedPickup> seeds = [];
  final List<FoodPickup> foods = [];
  late GoalFlag _goal;

  int _score = 0;
  int _seedsCollected = 0;
  int _curedCount = 0;
  bool _finished = false;
  double _enemyHitCooldown = 0;
  double _hudAccum = 0;

  // Green-Leaf health (the health system). Set in onLoad from profile defaults.
  late int _leaves;
  late int _maxLeaves;
  double _iFrames = 0;

  // Timed coaching hints (level 1 only); each entry is (atSeconds, text).
  final List<(double, String)> _hintSchedule = [];
  String _hint = '';
  double _elapsed = 0;
  bool _flagNudgeShown = false;

  static const double auraCureRadius = 165;

  int get _totalEnemies => enemies.length;
  bool get _allCured => enemies.every((e) => e.cured);
  String get _goalText =>
      _totalEnemies == 0 ? 'Flag tak pahuncho' : 'Sabko theek karo: $_curedCount/$_totalEnemies';

  @override
  Color backgroundColor() => const Color(0xFFFFE8B0);

  @override
  Future<void> onLoad() async {
    final worldDef = config.world(level.world);

    // Green-Leaf health from profile defaults.
    _maxLeaves = config.profileDefaults.startMaxLeaves;
    _leaves = config.profileDefaults.startLeaves.clamp(1, _maxLeaves);

    // Optional sprite art (vector fallback if PNGs absent).
    art = ArtRegistry(config.artMap);
    await art.preload();

    // Backdrop.
    world.add(_Backdrop(
      levelSize: Vector2(level.width, level.height),
      top: _hex(worldDef?.skyTop ?? '#FFE8B0'),
      bottom: _hex(worldDef?.skyBottom ?? '#F5C16C'),
      background: art.sprite('bg_tea_post'),
    ));

    // Platforms (visual + collision rects).
    final groundColor = _hex(worldDef?.groundColor ?? '#7A5230');
    for (final p in level.platforms) {
      final rect = Rect.fromLTWH(p.rect.x, p.rect.y, p.rect.w, p.rect.h);
      platformRects.add(rect);
      world.add(PlatformBlock(
        topLeft: Vector2(p.rect.x, p.rect.y),
        blockSize: Vector2(p.rect.w, p.rect.h),
        isGround: p.type == 'ground',
        groundColor: groundColor,
      ));
    }

    // Goal flag.
    _goal = GoalFlag(
      topLeft: Vector2(level.goal.x, level.goal.y),
      flagSize: Vector2(level.goal.w, level.goal.h),
    );
    world.add(_goal);

    // Pickups.
    for (final pk in level.pickups) {
      if (pk.kind == 'seed') {
        final s = SeedPickup(spawn: Vector2(pk.x, pk.y));
        seeds.add(s);
        world.add(s);
      } else if (pk.kind == 'food') {
        final item = config.food.byId(pk.id);
        if (item != null) {
          final f = FoodPickup(spawn: Vector2(pk.x, pk.y), item: item);
          foods.add(f);
          world.add(f);
        }
      }
    }

    // Enemies — count scaled by difficulty.
    final keep = difficulty.scaledEnemyCount(level.enemies.length);
    for (var i = 0; i < keep; i++) {
      final e = level.enemies[i];
      final lit = Litterer(
        spawn: Vector2(e.x, e.y),
        patrol: e.patrol,
        line: e.line,
        dropsSeed: e.dropsSeed,
      );
      enemies.add(lit);
      world.add(lit);
    }

    // Effects + player on top.
    effects = EffectsManager();
    world.add(effects);

    player = Shefali(spawn: Vector2(level.spawn.x, level.spawn.y));
    world.add(player);

    camera.follow(player);

    // Ambient + start dialogue.
    if (worldDef != null && worldDef.ambient.isNotEmpty) {
      await ambient.crossFadeTo(worldDef.ambient);
    }
    final startLine = config.dialogues.byId(level.dialogueOnStart);
    if (startLine != null) {
      onDialogue(startLine);
      audio.voice(startLine.voice);
    }

    // Coaching hints on the first level so the cure loop is discoverable.
    if (level.index == 1 && _totalEnemies > 0) {
      _hintSchedule.addAll(const [
        (1.5, 'Meditate (🧘) dabaye rakho — aura bharo'),
        (6.0, 'Enemy ke paas jao, phir Cure (✨) dabao'),
        (11.0, 'Sabko theek karke flag tak pahuncho 🌿'),
      ]);
    }
    _pushHud();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;

    _elapsed += dt;
    _updateHints();

    energy.update(dt, meditating: player.isMeditating);
    if (_enemyHitCooldown > 0) _enemyHitCooldown -= dt;
    if (_iFrames > 0) _iFrames -= dt;

    _checkSeeds();
    _checkFoods();
    _checkEnemyContact();
    _checkGoal();

    // Throttle HUD updates to ~30 Hz to limit widget rebuilds.
    _hudAccum += dt;
    if (_hudAccum >= 1 / 30) {
      _hudAccum = 0;
      _pushHud();
    }
  }

  // ---- Input API (called by the on-screen controls) ----

  void setHorizontal(int dir) => player.horizontalInput = dir.clamp(-1, 1);
  void jump() => player.jump();
  void yogaJump() => player.yogaJump();
  void setCrouch(bool v) => player.setCrouch(v);
  void setMeditate(bool v) => player.wantsMeditate = v;

  /// Release the charged aura: cure every enemy in range (bad -> good).
  void releaseAura() {
    if (!energy.tryCure()) return;
    player.onCureReleased();
    effects.spawnCureRing(player.worldCenter);
    audio.sfx('aura_release');
    haptic();

    final center = player.worldCenter;
    for (final e in enemies) {
      if (e.cured) continue;
      final d = (e.worldCenter - center).length;
      if (d <= auraCureRadius) {
        if (e.cure()) {
          _curedCount++;
          _score += 50;
          audio.sfx('cure');
          effects.spawnSparkle(e.worldCenter);
          // Plant a tree where the litterer stood — Shefali's clean-up.
          world.add(PlantedTree(base: Vector2(e.position.x, e.position.y)));
          final cured = config.dialogues.byId('enemy_cured');
          if (cured != null) onDialogue(cured);
          if (e.dropsSeed) {
            final s = SeedPickup(spawn: Vector2(e.worldCenter.x, e.worldCenter.y - 10));
            seeds.add(s);
            world.add(s);
          }
        }
      }
    }
    _pushHud();
  }

  void onEnemySpeak(String lineId) {
    final line = config.dialogues.byId(lineId);
    if (line != null) {
      onDialogue(line);
      audio.voice(line.voice);
    }
  }

  void onPlayerFell() {
    if (_finished) return;
    // Falling off the world costs a leaf and respawns at the level spawn.
    player.position = Vector2(level.spawn.x, level.spawn.y);
    player.velocity.setZero();
    _damage(1);
  }

  void haptic() {
    if (hapticsOn) HapticFeedback.lightImpact();
  }

  // ---- Collision checks (manual AABB; deterministic & testable) ----

  void _checkSeeds() {
    final pr = player.aabb;
    for (final s in seeds) {
      if (!s.collected && pr.overlaps(s.aabb)) {
        s.collected = true;
        s.removeFromParent();
        _seedsCollected++;
        _score += 10;
        audio.sfx('seed');
        effects.spawnSparkle(s.position);
        haptic();
      }
    }
  }

  void _checkFoods() {
    final pr = player.aabb;
    for (final f in foods) {
      if (!f.collected && pr.overlaps(f.aabb)) {
        f.collected = true;
        f.removeFromParent();
        f.item.applyTo(energy);
        _score += 5;
        audio.sfx(f.item.sfx);
        effects.spawnSparkle(f.position);
        haptic();
      }
    }
  }

  void _checkEnemyContact() {
    if (_enemyHitCooldown > 0) return;
    final pr = player.aabb;
    for (final e in enemies) {
      if (!e.cured && pr.overlaps(e.aabb)) {
        // Not killed — touching an uncured polluter costs a leaf and nudges back.
        _enemyHitCooldown = 0.8;
        final dir = player.worldCenter.x >= e.worldCenter.x ? 1.0 : -1.0;
        player.position.x += dir * 24;
        effects.spawnDust(player.worldCenter);
        _damage(1);
        break;
      }
    }
  }

  void _checkGoal() {
    if (!player.aabb.overlaps(_goal.aabb)) return;
    if (!_allCured) {
      // Must heal everyone first; nudge the player and keep playing.
      if (!_flagNudgeShown) {
        _flagNudgeShown = true;
        _showHint('Pehle sabko theek karo! 🌿', 2.5);
      }
      return;
    }
    _finished = true;
    audio.sfx('badge');
    onLevelComplete(LevelResult(
      levelId: level.id,
      levelIndex: level.index,
      levelName: level.name,
      seedsCollected: _seedsCollected,
      seedsTotal: level.seedCount,
      score: _score,
      curedEnemies: _curedCount,
    ));
  }

  // ---- Trash thrown by litterers ----

  void spawnTrash(Vector2 from, double dir) {
    world.add(TrashProjectile(from: from, dir: dir));
  }

  void onTrashHit(Vector2 at) {
    if (_finished) return;
    effects.spawnDust(at);
    _damage(1);
  }

  /// Lose a Green Leaf (health). i-frames prevent rapid multi-hits. At 0 leaves
  /// the level is lost.
  void _damage(int leaves) {
    if (_iFrames > 0 || _finished) return;
    _leaves = (_leaves - leaves).clamp(0, _maxLeaves);
    _iFrames = 1.0;
    haptic();
    _pushHud();
    if (_leaves <= 0) {
      _finished = true;
      onGameOver();
    }
  }

  // ---- Hints ----

  void _updateHints() {
    if (_hint.isNotEmpty && _elapsed >= _hintClearAt) _hint = '';
    if (_hintSchedule.isEmpty) return;
    final next = _hintSchedule.first;
    if (_elapsed >= next.$1) {
      _hintSchedule.removeAt(0);
      _showHint(next.$2, 4.0);
    }
  }

  double _hintClearAt = 0;
  void _showHint(String text, double seconds) {
    _hint = text;
    _hintClearAt = _elapsed + seconds;
  }

  void _pushHud() {
    hud.value = HudState(
      energy: energy.energyFraction,
      aura: energy.auraFraction,
      score: _score,
      seedsCollected: _seedsCollected,
      seedsTotal: level.seedCount,
      canCure: energy.canCure,
      cooldown: energy.cooldownRemaining,
      curedEnemies: _curedCount,
      totalEnemies: enemies.length,
      goal: _goalText,
      hint: _hint,
      leaves: _leaves,
      maxLeaves: _maxLeaves,
      level: profileLevel,
      xpFraction: profileXpFraction,
      coins: profileCoins,
      playerName: playerName,
    );
  }

  static Color _hex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

/// Gradient backdrop the size of the level, with simple vector scenery (hills +
/// a tea-stall silhouette). If a 'bg_tea_post' sprite is supplied it is tiled
/// across instead.
class _Backdrop extends PositionComponent {
  _Backdrop({
    required Vector2 levelSize,
    required this.top,
    required this.bottom,
    this.background,
  }) {
    size = levelSize;
    position = Vector2.zero();
  }
  final Color top;
  final Color bottom;
  final Sprite? background;

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    if (background != null) {
      // Tile the supplied background image across the level width.
      final imgW = background!.srcSize.x;
      final imgH = background!.srcSize.y;
      final scale = size.y / imgH;
      final tileW = imgW * scale;
      for (var x = 0.0; x < size.x; x += tileW) {
        background!.render(canvas, position: Vector2(x, 0), size: Vector2(tileW, size.y));
      }
      return;
    }

    // Clouds.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < (size.x / 600).ceil(); i++) {
      final cx = 200.0 + i * 600;
      canvas.drawCircle(Offset(cx, 110), 34, cloud);
      canvas.drawCircle(Offset(cx + 40, 120), 28, cloud);
      canvas.drawCircle(Offset(cx - 40, 122), 26, cloud);
    }

    // Rolling hills (two parallax-free bands).
    final hillBack = Paint()..color = const Color(0xFF8D6E63).withValues(alpha: 0.35);
    final hillFront = Paint()..color = const Color(0xFF6D8B3C).withValues(alpha: 0.4);
    final ground = size.y - 80;
    final pathBack = Path()..moveTo(0, ground);
    for (var x = 0.0; x <= size.x; x += 300) {
      pathBack.quadraticBezierTo(x + 150, ground - 90, x + 300, ground);
    }
    pathBack..lineTo(size.x, size.y)..lineTo(0, size.y)..close();
    canvas.drawPath(pathBack, hillBack);
    final pathFront = Path()..moveTo(0, ground + 20);
    for (var x = 0.0; x <= size.x; x += 420) {
      pathFront.quadraticBezierTo(x + 210, ground - 40, x + 420, ground + 20);
    }
    pathFront..lineTo(size.x, size.y)..lineTo(0, size.y)..close();
    canvas.drawPath(pathFront, hillFront);
  }
}
