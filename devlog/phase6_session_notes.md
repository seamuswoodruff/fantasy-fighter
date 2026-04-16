# Phase 6 Session Notes — HUD + Combat Polish

## What Was Built
- Full HUD in `scenes/ui/HUD.tscn` + `scripts/ui/HUD.gd`
  - Health bars using `TextureProgressBar` with `greenbar_1.png` fill (swaps to `redblue_1.png` below 25% HP)
  - Dark maroon trough (`ColorRect` with `show_behind_parent = true`) shows original bar extent
  - Black border (`Panel` + `StyleBoxFlat draw_center=false`) frames the bar
  - `nine_patch_stretch = true` so fill texture scales cleanly across the full bar
  - 3 pixel-art heart icons per player (procedurally generated 7×7 ImageTexture, `TEXTURE_FILTER_NEAREST`)
  - All visual nodes are real scene nodes — fully editable in the Godot editor
- Character spawn polish: P2 spawns and respawns facing left; sprite feet sit on top of grass

---

## Issues Fixed This Session

### 1. Hearts Not Rendering in Pixel-Art Style
**Symptom:** Hearts showed as squares or wrong glyphs — `alagard.ttf` does not contain a ♥ glyph, so Godot silently fell back to the system font.

**Fix:** Replaced Label-based hearts with `TextureRect` nodes. Generated the heart texture entirely in code using `Image.create()` → `set_pixel()` → `ImageTexture.create_from_image()`. Applied `TEXTURE_FILTER_NEAREST` and `stretch_mode = KEEP_ASPECT_CENTERED` for crisp pixel scaling.

---

### 2. Hearts Depleting in Wrong Order
**Symptom:** The middle heart was the last to grey out instead of the rightmost.

**Root Cause:** Two compounding bugs:
1. `P2Heart1` (x=1199) and `P2Heart2` (x=1177) were named out of spatial order in the scene.
2. The P1 `_on_stock_lost` formula used `remaining` directly instead of `2 - remaining`.

**Fix:** Sort all heart `TextureRect` nodes by `position.x` in `_ready()` so index 0 is always leftmost regardless of node naming. Unified depletion formula for both players: `grey_idx = 2 - remaining`.

---

### 3. Double Stock Loss on Void Death
**Symptom:** Falling into the void deducted 2 stocks instead of 1.

**Root Cause:** Two overlapping kill zones (e.g., KillBottom + KillLeft at a corner) both fired `body_entered` in the same physics frame. The second callback reached `die()` before `State.DEAD` was set by the first.

**Fix:** Moved `change_state(State.DEAD)` to the very first line of `die()`, immediately after the `if state == State.DEAD: return` guard. The second callback sees DEAD and returns.

---

### 4. Death Animation Triggering on Respawn Platform
**Symptom:** After a void death, the character briefly played the death animation on the respawn platform before transitioning to idle.

**Root Cause:** The physics body was frozen via `process_mode = DISABLED` while still inside a kill zone. When `respawn()` re-enabled it, `body_entered` fired again for the same kill zone.

**Fix:**
1. Teleport to `respawn_position` *before* setting `process_mode = DISABLED` (0.7s timer) so the body is never frozen inside a kill zone.
2. Added `or character.is_invincible` check in `BattleScene._on_kill_zone_entered()` — post-respawn i-frames block the kill zone from firing.

---

### 5. Death Not Synced to Bar Depletion
**Symptom:** Characters died slightly before the health bar fully emptied.

**Root Cause:** `take_damage()` called `die()` when `current_hp <= 0.0`, but floating-point subtraction could leave a small positive remainder that the progress bar still showed as non-zero.

**Fix:** After subtracting damage, snap any `current_hp < 1.0` to exactly `0.0`. The bar then hits zero at the same moment `die()` is called.

---

### 6. StyleBoxEmpty Stripped by Editor
**Symptom:** Attempts to override the Panel's normal style with `StyleBoxEmpty` were silently removed when Godot saved the scene.

**Root Cause:** Godot 4's scene serialiser discards `StyleBoxEmpty` sub-resources on save.

**Fix:** Abandoned the Panel-trough approach entirely. Used a `ColorRect` child with `show_behind_parent = true` instead — requires no style overrides and is editable directly in the Inspector.

---

### 7. P2 Respawning Facing Wrong Direction
**Symptom:** P2 correctly faced left at match start but reverted to facing right after each respawn.

**Fix:** Added `spawn_facing_right: bool = true` to `Character.gd`. `respawn()` calls `_set_facing(spawn_facing_right)` before `change_state(IDLE)`. `BattleScene._ready()` sets `player2.spawn_facing_right = false` alongside the initial `_set_facing(false)` call.

---

## Key Architecture Notes for Future Sessions

### HUD Wiring Pattern
`HUD.gd` is pure runtime logic — no node creation. It receives references via `set_characters(p1, p2)` called from `BattleScene._ready()` after spawn points are assigned. It polls `current_hp / max_hp` each `_process` frame to update bars, and connects to `GameManager.stock_lost` for heart greying.

### Pixel-Art Heart Generation
```gdscript
func _create_heart_texture() -> ImageTexture:
    var pattern = [[0,1,1,0,1,1,0], [1,1,1,1,1,1,1], ...]
    var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
    for y in 7:
        for x in 7:
            img.set_pixel(x, y, color_for_pixel(pattern[y][x], x, y))
    return ImageTexture.create_from_image(img)
```
Apply `TEXTURE_FILTER_NEAREST` on the `TextureRect` node for crisp scaling. The 7×7 image renders at 21×21px at 3× (set via node size in the scene).

### Heart Ordering — Always Sort by Position
Never rely on node name order for spatial layout. Always sort heart arrays by `position.x`:
```gdscript
rects.sort_custom(func(a, b): return (a as Control).position.x < (b as Control).position.x)
```

### Spawn Facing Direction
Each character has `spawn_facing_right: bool = true`. Set it to `false` for right-side players in BattleScene. The `respawn()` function automatically restores it — no per-player logic needed in the scene controller.

### Knight1 Sprite Offsets (updated)
- `AnimatedSprite2D position = Vector2(16, -26)` — 16px right for left-biased art; -26 lifts feet to sit on top of grass (was -16, which caused 10px of ground clipping)

---

## Phase 7 — VFX & Audio Integration

### What to build next
1. **VFXManager** (already stubbed as autoload) — implement `play(type, position)`:
   - Load all PNG frames from `vfx/hit_sparks/`, `vfx/magic/`, `vfx/ko/`, `vfx/dust/` on startup
   - Spawn one-shot `AnimatedSprite2D`, auto-free on `animation_finished`
2. **Wire VFX triggers** in `Character.gd`:
   - `hit_sparks` → on any successful hit (in `_apply_hit`)
   - `ko` → on stock loss (in `die()`, after `GameManager.on_player_death`)
   - `dust` → on landing (detect floor transition in `_update_coyote`)
3. **AudioManager** (already stubbed) — implement `play_sfx(name)` / `play_music(name)`:
   - Preload all WAV files from `sfx/` subdirs into a dictionary
   - `play_sfx` → one-shot AudioStreamPlayer on SFX bus
   - `play_music` → crossfade on Music bus
4. **Wire audio triggers** per the SFX Trigger Map in CLAUDE.md:
   - Attack swings, impact hits, block sounds
   - Stage music + ambience on BattleScene load
5. **Screen shake** on heavy hits — `Camera2D` tween offset (can be added to Phase 7 or deferred to Phase 11 polish)

### Files to create
- `scripts/managers/VFXManager.gd` (replace stub)
- `scripts/managers/AudioManager.gd` (replace stub)
- `scenes/vfx/HitSpark.tscn` (optional reusable scene, or spawn dynamically)

### Known state going into Phase 7
- All 4 autoload singletons exist; VFXManager and AudioManager are stubs with no implementation
- BattleScene loads cleanly, both players fight correctly, HUD tracks HP and stocks
- No audio plays anywhere yet; no VFX spawn anywhere yet
- `assets/sfx/`, `assets/music/`, `assets/vfx/` are all populated and ready to use
