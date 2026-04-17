# Phase 7 Session Notes — VFX & Audio Integration

## What Was Built

### AudioManager (`scripts/managers/AudioManager.gd`)
- Replaced stub with full implementation
- Preloads all WAV files from `sfx/attacks/`, `sfx/footsteps/`, `sfx/impacts/`, `sfx/ui/` at startup into prefix-grouped dictionary (e.g. `"Sword Attack"` → `[stream1, stream2, stream3]`)
- `play_sfx(sfx_name)`: case-insensitive prefix lookup, picks randomly among variants
- `play_music(track_path)`: two-player crossfade — alternates between `_music_a` and `_music_b`, fades new player in (−80→0 db over 1s) and old player out (0→−80 db over 1s) via separate Tweens
- `play_ambience(amb_path)`: loops OGG on Ambience bus at −12 db
- `set_volume(category, db)`: sets volume on named bus (Master/Music/SFX/Ambience)
- Loads 48 SFX groups on startup

### VFXManager (`scripts/managers/VFXManager.gd`)
- Replaced stub with sprite-sheet-aware implementation
- Each PNG is a grid of frames; each **row** is one complete animation
- Frame size detected from sheet height: 576px tall → 64×64 frames (9 rows); 72px tall → 72×72 frames (1 row, magic horizontal strips)
- Loads 2283 total animations across 4 types at startup
- `play(type, position, scale, anim_idx)`: spawns `AnimatedSprite2D`, plays one row, auto-frees on `animation_finished`
- `play_single(type, position, scale, duration, anim_idx)`: spawns `Sprite2D` with one random frame from a row, frees after `duration` seconds
- `get_anim_count(type)`: returns number of animations loaded for a type
- `anim_idx = -1` means random; 0+ pins to a specific animation row

### Knight1 VFX/Audio Wiring (`scripts/characters/Character.gd`)
- **Attack swing**: `AudioManager.play_sfx("Sword Attack")` on `attack_light()` and `attack_heavy()`
- **Hit connect** (in `_apply_hit`, after `take_damage`): `VFXManager.play_single("hit_sparks", area.global_position)` + `AudioManager.play_sfx("Sword Impact Hit")`
- **KO** (in `die()`, after `GameManager.on_player_death`): `VFXManager.play("ko", global_position, 2.0, 19)`
- No dust/landing VFX (removed as unnecessary)

### Stage Audio (`scripts/stages/BattleScene.gd`)
- Windrise music pool: 9 tracks (Prairie3–5, BattleField1–5, EpicBattle) — random pick via `randi() % pool.size()`
- Ambience: `Forest Day.ogg` loops at −12 db under music

### Pinned VFX Selections
| Effect | Sheet | Row | anim_idx | Description |
|--------|-------|-----|----------|-------------|
| Hit sparks | `881.png` | 6 | 618 | Steel/grey claw burst |
| KO | `1103.png` | 1 | 19 | Purple starburst swirl |

---

## Issues Fixed This Session

### 1. VFX Flood Covering the Entire Screen
**Symptom:** On first run, hundreds of VFX sprites covered the whole screen within seconds of gameplay.

**Root Cause — dust:** Landing detection used a local `_prev_on_floor` variable but `is_on_floor()` flickers rapidly when a character runs across TileMap tile edges. Each flicker registered as a "landing" and spawned a new 24-frame animation. At 60fps with two characters running, this generated hundreds of overlapping animations within seconds.

**Fix:** Guarded the landing VFX with a state check: only fire when `state == State.JUMP or state == State.FALL`. This ensures dust only spawns on real airborne-to-grounded transitions, not tile-edge jitter. (Later: removed dust VFX entirely as design decision.)

**Root Cause — sheets:** VFXManager was loading each full PNG (768×576px) as a single texture frame. Displaying a 768×576 image at the hit position covered most of the screen. With multiple VFX spawned, the screen flooded.

**Fix:** Rewrote VFXManager to slice each PNG into a grid of 64×64 cells (for 576px-tall sheets). Each row of cells = one animation. `play_single` now picks one 64×64 cell rather than the full sheet.

---

### 2. AudioManager `name` Parameter Shadowing `Node.name`
**Symptom:** GDScript warning — `The local function parameter "name" is shadowing an already-declared property in the base class "Node"`.

**Fix:** Renamed `play_sfx(name)` parameter to `play_sfx(sfx_name)`.

---

### 3. Integer Division Warning in VFXManager
**Symptom:** `WARNING: Integer division. Decimal part will be discarded.` at `GDScript::reload` for the `cols` and `rows` division lines.

**Root Cause:** GDScript 4.6 warns on integer division even when both operands are `int`. `@warning_ignore` and explicit `int` type annotations did not suppress it in this context.

**Fix:** Changed to explicit float division then cast: `var cols := int(w / float(frame_size))`. This is unambiguous to the linter and produces identical results.

---

## Key Architecture Notes for Future Sessions

### VFX Sheet Format
All 576px-tall VFX PNGs use 64×64 frames with 9 rows per sheet:
- `hit_sparks`: 84 sheets × 9 rows = 756 animations
- `dust`: 24 sheets × 9 rows = 216 animations
- `ko`: 48 sheets × 9 rows = 432 animations
- `magic`: mix of 576px (64×64, 9 rows) and 72px tall (72×72, 1 row) strips

The `anim_idx` formula for pinning: `(sheet_number_0indexed * 9) + row_number`

### VFX Pinning Workflow
1. Open `assets/vfx/<type>/` in Finder, arrow-key through PNGs
2. Note the filename and row number (0-indexed from top)
3. Run `ls assets/vfx/<type>/*.png | sort | grep -n "<filename>"` to get the 1-indexed line number
4. `anim_idx = (line_number - 1) * 9 + row`
5. Pass to `play()` or `play_single()` as the last argument

### AudioManager SFX Lookup
SFX files are grouped by stripping trailing numbers: `"Sword Attack 1.wav"` → group `"Sword Attack"`. `play_sfx("Sword Attack")` picks randomly among all variants. Keys are case-insensitive. Use `print(AudioManager._sfx_groups.keys())` to inspect available group names at runtime.

### Music Crossfade
`play_music` alternates between `_music_a` and `_music_b`. Each call fades in the inactive player and fades out the active one over 1 second. Safe to call mid-match for dynamic music switching in future phases.

### Phase 6 Invariants — Preserved
All Phase 6 ordering rules were maintained:
- `die()` still sets `change_state(State.DEAD)` on its first line after the guard
- VFX/audio calls in `die()` are placed after `GameManager.on_player_death()`
- `_apply_hit` VFX/audio placed after `take_damage()` returns
- No HURT state exit from `animation_finished` (still timer-driven)

---

## Phase 8 — All 9 Characters

### What to build next
- `Knight.gd` already covers knight_1/2/3 (Warrior.gd handles this — rename to Knight.gd in Phase 8)
- New scripts: `Samurai.gd`, `SamuraiArcher.gd`, `FireWizard.gd`, `LightningMage.gd`, `WandererMagician.gd`
- `Projectile.gd` base class for arrows, fireballs, light balls, magic spheres
- Each character gets its own `.tscn` scene with correct sprite frames, stats, and script
- Wire VFX/audio into each character's attack and death callbacks (same pattern as knight_1)

### Known state going into Phase 8
- knight_1 fully playable with working VFX and audio
- All other 8 characters have no scene, no script, no animations
- VFXManager and AudioManager are fully implemented and ready to use
- `play_single("hit_sparks", pos, 2.0, 0.12, 618)` and `play("ko", pos, 2.0, 19)` are the pinned calls to reuse for all melee characters
