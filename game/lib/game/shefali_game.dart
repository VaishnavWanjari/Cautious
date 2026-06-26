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
import 'audio/ambient_controller.dart';
import 'audio/audio_manager.dart';
import 'effects/effects.dart';
import 'enemies/litterer.dart';
import 'hud/hud_state.dart';
import 'pickups/pickups.dart';
import 'platforms/platform_block.dart';
import 'player/shefali.dart';

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
  })  : energy = EnergySystem(balance: config.balance, difficulty: difficulty),
        super();

  final GameConfig config;
  final LevelModel level;
  final DifficultyProfile difficulty;
  final EnergySystem energy;
  final AudioManager audio;
  final AmbientAudioController ambient;
  final bool hapticsOn;

  /// Fired when an enemy speaks / on level-start line. UI shows a dialogue bubble.
  final void Function(DialogueLine line) onDialogue;
  final void Function(LevelResult result) onLevelComplete;
  final VoidCallback onGameOver;

  final ValueNotifier<HudState> hud = ValueNotifier(HudState.empty);

  late final Shefali player;
  late final EffectsManager effects;

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

  static const double auraCureRadius = 150;

  @override
  Color backgroundColor() => const Color(0xFFFFE8B0);

  @override
  Future<void> onLoad() async {
    final worldDef = config.world(level.world);

    // Backdrop.
    world.add(_Backdrop(
      levelSize: Vector2(level.width, level.height),
      top: _hex(worldDef?.skyTop ?? '#FFE8B0'),
      bottom: _hex(worldDef?.skyBottom ?? '#F5C16C'),
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
    _pushHud();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;

    energy.update(dt, meditating: player.isMeditating);
    if (_enemyHitCooldown > 0) _enemyHitCooldown -= dt;

    _checkSeeds();
    _checkFoods();
    _checkEnemyContact();
    _checkGoal();

    if (energy.isExhausted) {
      _finished = true;
      onGameOver();
      return;
    }

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
    // Falling off the world costs energy and respawns at the level spawn.
    energy.addEnergy(-25);
    player.position = Vector2(level.spawn.x, level.spawn.y);
    player.velocity.setZero();
    haptic();
    if (energy.isExhausted) {
      _finished = true;
      onGameOver();
    }
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
        // Not killed — touching an uncured litterer saps energy and nudges back.
        energy.addEnergy(-8);
        _enemyHitCooldown = 0.8;
        final dir = player.worldCenter.x >= e.worldCenter.x ? 1.0 : -1.0;
        player.position.x += dir * 24;
        effects.spawnDust(player.worldCenter);
        haptic();
        break;
      }
    }
  }

  void _checkGoal() {
    if (player.aabb.overlaps(_goal.aabb)) {
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
    );
  }

  static Color _hex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

/// Simple gradient backdrop the size of the level.
class _Backdrop extends PositionComponent {
  _Backdrop({required Vector2 levelSize, required this.top, required this.bottom}) {
    size = levelSize;
    position = Vector2.zero();
  }
  final Color top;
  final Color bottom;

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

    // A few distant clouds for parallax-free depth.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < (size.x / 600).ceil(); i++) {
      final cx = 200.0 + i * 600;
      canvas.drawCircle(Offset(cx, 110), 34, cloud);
      canvas.drawCircle(Offset(cx + 40, 120), 28, cloud);
      canvas.drawCircle(Offset(cx - 40, 122), 26, cloud);
    }
  }
}
