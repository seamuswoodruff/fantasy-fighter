# Ninja Characters Session Notes — Kunoichi, NinjaMonk, NinjaPeasant

## Overview

Added three ninja characters (Kunoichi, NinjaMonk, NinjaPeasant) bringing the
total roster to 12. Expanded CharacterSelect from a 3×3 grid (9 chars) to a
4×3 grid (12 chars). Added `_frames_raw()` helper to Character.gd for loading
sprite sheets that lack Godot `.import` sidecar files.

---

## New Helper: `_frames_raw()` in Character.gd

Ninja PNG sprites have no `.import` sidecar files, so `load("res://…")` fails
with "No loader found for resource." Character.gd already had `_load_raw_texture()`
for this case, but no way to count frames without a loaded texture. Added:

```gdscript
func _frames_raw(path: String, frame_size: int) -> int:
    var tex := _load_raw_texture(path)
    if tex == null:
        return 1
    return int(tex.get_width() / float(frame_size))
```

All three ninja `_build_sprite_frames()` methods use `_load_raw_texture()` +
`_frames_raw()` for every animation instead of `load()` + `_frames()`.

---

## Kunoichi

**File:** `scripts/characters/Kunoichi.gd`  
**Scene:** `scenes/characters/Kunoichi.tscn`  
**Stats:** HP 90, Speed 300, Jump -615, Light 9, Heavy 16  
**Frame size:** 128px

**Mechanics:**
- Special 1 (C): shuriken throw — `SHURIKEN_SPEED 600`, `SHURIKEN_DAMAGE 12`,
  `SHURIKEN_RANGE 950`. Fires after cast animation finishes.
- Special 2 (V): eating heal — plays `special 2.png` animation, restores
  `HEAL_AMOUNT 5` HP on finish. `HEAL_COOLDOWN 4.0s`. Uses `_healing` flag
  and `_heal_cooldown_timer` to gate re-use.

**Portrait position:** `sprite.position = Vector2(0, -26)` — standard 128px offset.

**Projectile (`_spawn_shuriken`):** `RectangleShape2D(28×16)`, scale 3×3,
direction set via `proj.direction = 1.0 if facing_right else -1.0`,
`flip_h = not facing_right`, spawned via `get_parent().add_child(proj)` then
`global_position = global_position + Vector2(30.0 * proj.direction, -20.0)`.

---

## NinjaMonk

**File:** `scripts/characters/NinjaMonk.gd`  
**Scene:** `scenes/characters/NinjaMonk.tscn`  
**Stats:** HP 105, Speed 275, Jump -595, Light 10, Heavy 18  
**Frame size:** 96px

**Mechanics:**
- Special 1 (C): staff throw — `STAFF_SPEED 480`, `STAFF_DAMAGE 14`,
  `STAFF_RANGE 950`. Staff sheet is 48×16 (not square) — uses
  `hframes = int(tex.get_width() / float(tex.get_height()))`.
- Special 2 (V): blade slash — `SPECIAL2_DAMAGE 18`. Uses `_special2_active`
  flag. Plays "special2" animation (from `special 2.png`). Overrides
  `_play_animation_for_state()` to play "special2" when state==SPECIAL and
  `_special2_active`. Hitbox_heavy active frames 2–6 of 9. Damage routed
  through `_apply_hit(area, SPECIAL2_DAMAGE, true)` — NOT `take_damage()`
  directly — so damage numbers, screen freeze, recoil, VFX all fire.

**`_on_sprite_animation_finished` logic:**
```gdscript
State.SPECIAL:
    if not _special2_active:
        _spawn_staff_projectile()   # only spawn if it was a throw, not slash
    _special2_active = false        # always reset
    change_state(State.IDLE)
```

**Sprite sizing:** 96px frames, art fills ~71px. Scale `(0.90, 0.90)`,
position `(0, -5)`. Feet land at: -5 + 48*0.9 = +38.2px (capsule bottom ~+32,
+6px margin matches knight_1 at -26 with 128px frames).

**Projectile (`_spawn_staff_projectile`):** `RectangleShape2D(36×14)`, scale 2×2.

---

## NinjaPeasant

**File:** `scripts/characters/NinjaPeasant.gd`  
**Scene:** `scenes/characters/NinjaPeasant.tscn`  
**Stats:** HP 85, Speed 295, Jump -610, Light 8, Heavy 15  
**Frame size:** 96px

**Mechanics:**
- Special 1 (C): stone throw — `STONE_SPEED 520`, `STONE_DAMAGE 11`,
  `STONE_RANGE 800`. Stone is a single-frame 6×6px sprite scaled 4×4 to 24×24.
- Special 2 (V, hold): block/defend — holds `is_blocking = true` while V held,
  60% damage reduction via base class. Uses `special 2.png` as "block" animation.
  Overrides `handle_input()`:

```gdscript
func handle_input() -> void:
    super.handle_input()
    if not _is_locked() and not is_cpu:
        if Input.is_action_pressed("p%d_special2" % player_id):
            is_blocking = true
```

`special2_attack()` is a no-op (pass) — blocking is input-driven, not triggered
by the attack method. This matches the Knight/Samurai block pattern.

**Sprite sizing:** 96px frames, art fills ~68px. Scale `(0.94, 0.94)`,
position `(0, -7)`. Feet land at: -7 + 48*0.94 = +38.1px.

**Projectile (`_spawn_stone`):** `RectangleShape2D(20×20)`, scale 4×4.

---

## CharacterSelect — 4-Column Grid Expansion

**File:** `scripts/ui/CharacterSelect.gd`

**Changes:**
- CHARACTERS array expanded from 9 to 12 entries (kunoichi, ninja_monk, ninja_peasant added)
- All grid math updated: 3 → 4 columns
  - `_cursors.append(Vector2i(i % 4, 0))`
  - `grid_offset_x = (_panel_w - 4 * CELL_SIZE) / 2`
  - `for col in 4`, `row * 4 + col`
  - Cursor wrap: `(x + delta.x + 4) % 4`
- Portrait scale normalized: `Vector2(PORTRAIT_PX / 128.0, PORTRAIT_PX / 128.0)`
  — was `PORTRAIT_PX / float(frame_px)` which made 96px ninja portraits oversized
- Portrait hframes uses `tex.get_height()` as frame size (works for both 128px and 96px)
- Added `_load_portrait_tex()` helper using `ResourceLoader.exists()` before
  attempting `load()` — prevents engine-level "No loader found" errors for
  un-imported ninja PNGs

---

## BattleScene / WinScreen Updates

**BattleScene.gd** — added to CHARACTER_SCENES:
```gdscript
"kunoichi":      "res://scenes/characters/Kunoichi.tscn",
"ninja_monk":    "res://scenes/characters/NinjaMonk.tscn",
"ninja_peasant": "res://scenes/characters/NinjaPeasant.tscn",
```

**WinScreen.gd** — added to CHAR_IDLE_PATHS:
```gdscript
"kunoichi":      "res://assets/characters/ninjas/kunoichi/sprites/Idle.png",
"ninja_monk":    "res://assets/characters/ninjas/ninja_monk/sprites/Idle.png",
"ninja_peasant": "res://assets/characters/ninjas/ninja_peasant/sprites/Idle.png",
```
WinScreen also updated to use `_load_tex_safe()` (ResourceLoader.exists() check)
and `tex.get_height()` as frame size for correct hframes on 96px sheets.

---

## Validation

All 12 characters pass `_validate_all_characters()` on BattleScene boot:
```
kunoichi      — HP:90  Spd:300
ninja_monk    — HP:105 Spd:275
ninja_peasant — HP:85  Spd:295
```
