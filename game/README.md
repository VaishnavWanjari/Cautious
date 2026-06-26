# Prakriti Ki Rakshak: Shefali 🌿

A 2D side-scrolling environmentalist platformer built with **Flutter + Flame**.
Shefali — a mechanical engineer — protects nature by **curing** polluters with a
meditation aura (never killing them), planting calm, and cleaning up the world.

This repository contains the **Phase 1 vertical slice**: Shefali's full move-set,
the aura + energy systems, the food system, the Litterer enemy, Magaj-seed
collectibles, the **Tea Post** world with **3 data-driven levels**, animated
menus, an intro cutscene, particles, dynamic weather, haptics, a Hindi dialogue
system, offline save, difficulty modes and the Player-2 unlock gate.

> **Heads-up:** this slice ships **programmatic placeholder art** and **empty
> audio slots**. Drop in real sprites/mp3s later with no code changes (see
> *Replacing placeholder art* and *Mapping audio*).

---

## Running the game

This package was authored without the Flutter SDK present, so the platform
folders (`android/`, `ios/`) are **generated on your machine**:

```bash
cd game
flutter create --platforms=android,ios --org com.prakriti.shefali .   # one-time
flutter pub get
flutter analyze        # expect: no issues found
flutter test           # logic + config cross-reference suite — expect: all pass
flutter run            # on an Android emulator / iOS simulator
```

`flutter create` only adds the native projects; it leaves `lib/`, `assets/`,
`pubspec.yaml` and `test/` untouched. Requires **Flutter ≥ 3.27** (the code uses
`Color.withValues`; on older Flutter, replace those with `withOpacity`).

### Controls (touch)

Left cluster: move ◀ ▶ and **crouch** (hold). Right cluster: **Jump**,
**Yoga-jump** (higher/floaty, costs energy), **Meditate** (hold to charge aura)
and **Cure** (release the aura to convert nearby enemies). Reach the flag to
finish and earn the level's appreciation badge.

---

## Project layout

```
lib/
  logic/   PURE DART, no Flame — fully unit-tested game rules
           (energy_system, food, difficulty, level_model, progress,
            unlocks, dialogue_model)
  data/    config_loader (JSON -> models) + prefs_store (saved progress)
  game/    Flame layer: shefali_game + player/ enemies/ pickups/
           platforms/ effects/ audio/ hud/
  ui/      Flutter screens & overlays (menus, level select, cutscene,
           gameplay HUD/controls/weather, galleries)
assets/config/   all editable content (levels, dialogues, bosses, food,
                 audio_map, secret_references, game_balance, worlds)
assets/audio/    voice/ ambient/ sfx/ music/ slots (drop mp3s here)
assets/sprites/  art slots (drop pngs here)
test/            unit tests + a config cross-reference test
```

The split is deliberate: **all rules live in `lib/logic/` with zero Flame/Flutter
imports**, so they are verified by `flutter test` without a device, and the Flame
layer just renders and feeds them input.

---

## Editing content (no engine knowledge needed)

### Add a level
1. Copy `assets/config/levels/level_03.json` to `level_04.json`.
2. Edit it (schema is documented in the `_comment` at the top of `level_01.json`):
   `width/height`, `spawn`, `goal`, `platforms[]` (solid AABBs),
   `enemies[]` (`type` must be implemented — Phase 1: `litterer`; `line` is a
   dialogue id), `pickups[]` (`seed`, or `food` with an `id` from `food.json`),
   `weather` (`none|rain|wind`).
3. Register the file path in `lib/data/config_loader.dart` → `GameConfig.levelFiles`.
   That's the only code touch; the level then appears in level-select automatically.

### Add a dialogue line
Add an entry to `assets/config/dialogues.json` with a unique `id`, `speaker`,
Hindi `text`, a `trigger` (`intro|level_start|enemy|boss|ending|generic`) and an
optional `voice` key. Reference it from a level (`enemies[].line` or
`dialogueOnStart`) or a cutscene trigger.

### Map audio (your mp3s)
`assets/config/audio_map.json` binds logical keys → file paths. To add a voice
clip: drop the mp3 at the path already listed (e.g.
`assets/audio/voice/shefali/cure_all.mp3`) and it plays — **no code change**. A
missing file is skipped silently, so you can add clips one at a time. New keys:
add them under `voice` / `ambient` / `sfx` / `music`, then reference the key from
a dialogue (`voice`), a world (`ambient`) or code (`sfx`). The voice/ subfolders
are already declared in `pubspec.yaml`; if you add a *new* folder, add it under
`flutter.assets` too.

### Edit bosses
`assets/config/bosses.json` — one boss per multiple-of-5 level. Rename/add freely
(boss fights themselves arrive in Phase 2; Phase 1 ships the data).

### Edit secret references
`assets/config/secret_references.json` — `{ id, trigger, type(text|image),
content }`. Empty `content` is ignored. Add/edit/remove freely; the engine reads
this file (schema is documented in its top comment).

### Tune difficulty / balance
`assets/config/game_balance.json` — the `defaults` block and the three
difficulty profiles (energy drain, aura charge/cost/cooldown, enemy
count/speed multipliers, timers).

### Replacing placeholder art
Drop PNGs into `assets/sprites/<group>/` (slots: `shefali/`, `enemies/`,
`pickups/`, `env/`). The placeholder slots referenced by config are listed in
`food.json` (`sprite`), `dialogues.json` (`portrait`) and `bosses.json`
(`portrait`). Wiring sprite rendering into the Flame components is a small,
localized change in `lib/game/.../*.dart` (each component's `render`).

---

## QC

- **Static / data:** `test/config_files_test.dart` loads every real config file
  and asserts the cross-references hold (enemy lines exist, food ids exist,
  every dialogue `voice`/world `ambient`/food `sfx` key resolves in
  `audio_map.json`, levels are in-bounds and sequentially indexed).
- **Logic:** `energy_system_test`, `food_test`,
  `difficulty_unlocks_progress_test`, `level_model_test` cover the pure rules.
- **CI:** `.github/workflows/game-ci.yml` runs `flutter pub get`, `analyze` and
  `test` on every push touching `game/**`.

Run locally with `flutter test` and `flutter analyze`.

---

## Roadmap (Phase 2 / 3)

Remaining 7 worlds + scaling to 50 levels, boss fights + clean-up puzzles,
engineering mini-puzzles, true Tiled (`.tmx`) maps via `flame_tiled`, local
co-op (Vaishnav, Player 2 — already gated to unlock after Level 5), optional
Google login + cloud save, and the secret wedding ending at the Tea Post.
