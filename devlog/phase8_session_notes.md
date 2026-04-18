# Phase 8 Session Notes — All 9 Characters + Wizard Controls Fix

## What Was Built

### All 9 Character Scripts — 6-Script Model

All 9 characters are implemented and validate cleanly on every startup. Each script
extends `Character.gd` and wires its own sprite frames, stats, and unique mechanics.

#### `Knight.gd` — knight_1, knight_2, knight_3
- Stats: HP 150, Speed 200, Jump -550, Light 12, Heavy 22
- Animations: Idle, Walk, Run, Jump, Attack 1, Attack 2, Attack 3, Defend, Protect, Run+Attack, Hurt, Dead
- Block mechanic via `Defend`/`Protect` animations — reduces incoming damage 60%
- Run+Attack animation plays when attack input pressed during RUN state
- Attack 3 is a manual combo finisher (press heavy again after heavy)

#### `Samurai.gd` — samurai, samurai_commander
- Stats: HP 120, Speed 260, Jump -580, Light 10, Heavy 18
- Detects at runtime whether `Protection.png` or `Protect.png` exists — uses correct name for each character variant
- Special (Attack_3): fast multi-hit dash forward — moves character 80px over animation, hits up to 3× for 6 dmg each
- Block via `Protection`/`Protect` animation, 60% damage reduction

#### `SamuraiArcher.gd` — samurai_archer
- Stats: HP 110, Speed 280, Jump -600, Light 9, Heavy 16, Arrow 14
- Special: `Shot` animation → spawns Arrow projectile (600px/s, 1000px range)
- Arrow uses `Arrow.png` sprite sheet; no block animation

#### `FireWizard.gd` — fire_wizard
- Stats: HP 100, Speed 220, Jump -600, Light 8, Heavy 14
- C: `Fireball` cast animation → spawns `Fireball_projectile.png` (450px/s, 18 dmg, 900px range)
- V: `Flame_jet` sustained AOE — `hitbox_light` active for 1s, 8 dmg per 0.2s tick, no extra VFX

#### `LightningMage.gd` — lightning_mage
- Stats: HP 100, Speed 215, Jump -600, Light 8, Heavy 14
- C: `Light_ball` cast animation → spawns `Light_ball_projectile.png` (500px/s, 12 dmg, radius 18)
- V: `Light_charge` animation — `hitbox_heavy` activates during active frames (frames 1 to total-2), 28 dmg + 1s extra hitstun
- Overrides `_on_sprite_frame_changed()` for hitbox window, `_on_hitbox_heavy_area_entered()` for charge damage

#### `WandererMagician.gd` — wanderer_magician
- Stats: HP 105, Speed 225, Jump -595, Light 9, Heavy 15
- C: `Magic_arrow` cast → spawns `Magic_arrow_projectile.png` (550px/s, 10 dmg, rect hitbox, 0.25s cooldown)
- V: `Magic_sphere` cast → spawns `Magic_sphere_projectile.png` (250px/s, 22 dmg, circle hitbox, piercing)

### `Projectile.gd` — Base Projectile Class
- `Area2D` with `collision_layer = 4`, `collision_mask = 3` (hurtboxes + platforms)
- Properties: `speed`, `damage`, `max_distance`, `is_piercing`, `owner_id`, `extra_hitstun`
- Manually advances `Sprite2D.frame` each physics tick for animation (Sprite2D has no built-in playback)
- `area_entered` → `take_damage()` on hurtbox contact, optional `_apply_extra_hitstun`, VFX + SFX
- `body_entered` → `queue_free()` on `StaticBody2D` contact (platform/wall collision)
- `is_piercing = true` skips `queue_free()` on hurtbox hit (Magic Sphere passes through)

### Input Additions
- Added `p1_special2` (V key) and `p2_special2` (semicolon) to `project.godot`
- Both actions also mapped to joypad button 10 for controller support
- `InputManager.is_special2_pressed(player_id)` added
- `Character.gd` `handle_input()` now calls `special2_attack()` on this input
- `Character.gd` base `special2_attack()` is a no-op; overridden in wizard scripts

---

## Issues Fixed This Session

### 1. Blue Placeholder ColorRect Visible on All Wizards
**Symptom:** Bright blue box appeared over all wizard characters in battle.

**Root Cause:** `Character.tscn` has a `Placeholder` ColorRect child that was still visible. It was not deleted because doing so would shift child node indices 4 and 5 (HitboxLight/HitboxHeavy), breaking all 9 character `.tscn` files.

**Fix:** Set `visible = false` on the Placeholder node in `Character.tscn`.

---

### 2. Projectile Loaded Wrong PNG (`Fireball.png` Instead of `Fireball_projectile.png`)
**Symptom:** Firing the fireball showed the wizard's own cast-pose sprite flying across the screen.

**Root Cause:** `Fireball.png` is the cast animation (wizard throwing pose). The flying fireball is `Fireball_projectile.png`. The initial script referenced the wrong file.

**Fix:** All wizard projectile scripts now reference `*_projectile.png` explicitly.

---

### 3. `No loader found` Error for `_projectile.png` Files
**Symptom:** `ERROR: No loader found for resource 'res://...Fireball_projectile.png'`

**Root Cause:** Projectile PNGs had no `.import` sidecar files — Godot's resource system couldn't load them via `load()`.

**Fix:** Added `_load_raw_texture(res_path)` helper to `Character.gd` that uses `Image.new(); img.load(ProjectSettings.globalize_path(res_path))` then `ImageTexture.create_from_image(img)` to bypass the importer. Works in debug mode; would need proper import for exported builds.

---

### 4. Projectile Sprite Showed No Animation
**Symptom:** Projectile flew across screen as a static still image.

**Root Cause:** `Sprite2D` has no built-in frame playback. Setting `hframes` and `texture` only draws one frame unless `frame` is manually incremented.

**Fix:** `Projectile.gd` `_physics_process()` now advances `spr.frame = (spr.frame + 1) % spr.hframes` on a per-frame timer based on `anim_fps`.

---

### 5. Double-Projectile Artifact (Two Sprites Per Shot)
**Symptom:** Each projectile fired showed two overlapping sprites side by side.

**Root Cause:** `_calc_hframes()` originally used `width / height` to calculate frame count. For `Magic_arrow_projectile.png` (384×128), this gave `hframes = 3`. But the frames are actually 64px wide (6 frames), not 128px wide. With `hframes = 3`, each "frame" region was 128px wide — showing 2 actual frames at once.

**Root Cause (general):** All four projectile sprite sheets use 64px-wide frames regardless of sheet height:
| Sheet | Dimensions | Correct frames | Wrong calc |
|-------|-----------|----------------|------------|
| `Magic_arrow_projectile.png` | 384×128 | 6 (64px wide) | 3 (128px wide) |
| `Magic_sphere_projectile.png` | 576×128 | 9 (64px wide) | fallback 9 ✓ |
| `Fireball_projectile.png` | 768×64 | 12 (64px wide) | 12 ✓ |
| `Light_ball_projectile.png` | 576×64 | 9 (64px wide) | 9 ✓ |

**Fix:** All wizard scripts now use `int(tex.get_width() / 64.0)` for projectile `hframes` instead of `_calc_hframes(tex)`.

---

### 6. Projectiles Passing Through Platforms
**Symptom:** Arrows, fireballs, and magic projectiles flew through platform surfaces.

**Root Cause:** `Projectile` had `collision_mask = 2` (hurtboxes only). Platforms are `StaticBody2D` on layer 1, which the projectile never scanned.

**Fix:** `collision_mask` expanded to `3` (layers 1 + 2). Connected `body_entered` signal; `_on_body_entered()` calls `queue_free()` only when `body is StaticBody2D` — avoiding false triggers from character `CharacterBody2D` bodies (also on layer 1).

---

## Key Architecture Notes for Future Sessions

### Projectile Frame Size Rule
All `*_projectile.png` sprite sheets in this project use **64px-wide frames**. When loading
any projectile texture, always calculate `hframes = int(tex.get_width() / 64.0)`.

### `_load_raw_texture` / `_calc_hframes`
Both helpers live in `Character.gd`:
- `_load_raw_texture(res_path)` — bypasses Godot importer, required for any PNG without a `.import` sidecar
- `_calc_hframes(tex)` — general helper using `width / height` for square frames; use `width / 64.0` explicitly for projectile sheets

### Wizard Input Mapping
| Player | Light melee | Heavy melee | Special 1 | Special 2 |
|--------|------------|-------------|-----------|-----------|
| P1 | Z | X | C | V |
| P2 | , | . | / | ; |
No numpad keys used anywhere in the project.

### All 9 Characters Validate on Every Boot
`BattleScene._validate_all_characters()` runs at startup and logs HP/Speed for all 9.
If any character fails to load, a `push_error` appears. Current output:
```
knight_1 — HP:150 Spd:200
knight_2 — HP:150 Spd:200
knight_3 — HP:150 Spd:200
samurai — HP:120 Spd:260
samurai_commander — HP:120 Spd:260
samurai_archer — HP:110 Spd:280
fire_wizard — HP:100 Spd:220
lightning_mage — HP:100 Spd:215
wanderer_magician — HP:105 Spd:225
```

### Stale UID Warnings in BattleScene.tscn
Three `invalid UID` warnings appear on every boot — non-fatal, engine falls back to path
lookup. Not addressed; does not affect gameplay.

---

## Phase 9 — All 3 Stages

### What to build next
- `scenes/stages/Ruins.tscn` — lush overgrown ruins, floating castles, `ruins_platform_tiles.png` tileset
- `scenes/stages/DesertTemple.tscn` — sandy desert, `desert_platforms.png` 256×256 grid
- Each stage needs: ParallaxBackground layers, TileMap (visual only), StaticBody2D platform collision, kill zones, spawn points, stage-specific music pool
- Follow Platform Building Protocol: measure tile size first, build one section at a time, screenshot after each, never scale sprites

### Known state going into Phase 9
- Windrise stage fully working
- BattleScene defaults hardcoded for dev previews — will be replaced by CharacterSelect/StageSelect in Phase 10
- All 9 characters playable and validated
