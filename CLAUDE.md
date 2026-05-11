# Fantasy Fighter — Claude Code Project Brief

## Workflow Rules

### After every script or scene, verify immediately
Run `run_project`, then `get_debug_output`. Fix all errors before writing the
next script. Never batch multiple scripts without testing between them.

### After every stage or UI screen, take a screenshot
Use `ScreenshotTool.take_screenshot("label")` or F12 in-game. Read the saved
PNG and assess before continuing. Fix visual problems before moving on.

### GDScript API errors
When a method call fails, read the exact error in `get_debug_output` and verify
the correct method name against Godot 4 docs. Do not guess at alternatives.
Prefix any uncertain API call with `# verify: method name unconfirmed` so it
can be audited.

### Godot MCP Tools

| Tool | Use for |
|------|---------|
| `run_project` | Run and test the game |
| `get_debug_output` | Read console errors and print output |
| `stop_project` | Stop a running game |
| `create_scene` | Create new .tscn files |
| `add_node` | Add nodes to existing scenes |
| `load_sprite` | Assign a texture to a Sprite2D |
| `save_scene` | Save scene changes |
| `get_project_info` | Inspect project structure |
| `get_uid` / `update_project_uids` | Fix UID reference errors (Godot 4.4+) |

Write all GDScript by editing .gd files directly. Use MCP tools for scene
structure (nodes, sprites). Use `run_project` + `get_debug_output` to test.

### End of every phase
1. `run_project` → `get_debug_output` — must be error-free
2. `ScreenshotTool.take_screenshot("phase_N_complete")`
3. Git commit with descriptive message

---

## Skill Requirement — Read Before Writing Any Code

**Before writing any GDScript, creating any scene, or implementing any game mechanic, you MUST invoke the `game-development` skill.** This applies every time you begin a new coding task, not just at session start.

The game-development skill contains Godot-specific patterns for state machines, player controllers, object pooling, event systems, and performance optimization. All code written for this project must follow those patterns. Do not write game code from scratch without consulting the skill first.

To invoke: use the Skill tool with `skill: "game-development"` before each implementation phase.

---

## Project Overview

A 2D local-multiplayer platform fighter built in Godot 4.6.2 using GDScript. Two players fight on a stage, dealing damage to deplete each other's HP. Death occurs when HP reaches 0 or a player falls off the stage. The game must run on macOS, support local multiplayer, and support game controllers.

**Timeline:** 3-week class project  
**Engine:** Godot 4.6.2  
**Language:** GDScript  
**Platform:** macOS (primary), cross-platform compatible  
**Multiplayer:** Local only (2 players, same machine)  
**Input:** Keyboard (Player 1: WASD+keys, Player 2: arrow keys) AND controllers (Xbox/PS/generic gamepad via Godot's InputMap)

---

## Project Structure

```
fantasy-fighter/
├── CLAUDE.md                    ← this file
├── project.godot
├── assets/
│   ├── characters/
│   │   ├── warriors/
│   │   │   ├── knight_1/sprites/    (12 animation PNGs)
│   │   │   ├── knight_2/sprites/    (12 animation PNGs)
│   │   │   └── knight_3/sprites/    (12 animation PNGs)
│   │   ├── wizards/
│   │   │   ├── fire_wizard/sprites/       (11 animation PNGs)
│   │   │   ├── lightning_mage/sprites/    (11 animation PNGs)
│   │   │   └── wanderer_magician/sprites/ (12 animation PNGs)
│   │   └── samurai/
│   │       ├── samurai/sprites/           (10 animation PNGs)
│   │       ├── samurai_archer/sprites/    (11 animation PNGs)
│   │       └── samurai_commander/sprites/ (10 animation PNGs)
│   ├── stages/
│   │   ├── windrise/
│   │   │   ├── background/ (windrise-background.png, mountains.png, hills.png)
│   │   │   ├── platforms/  (floating_platforms.png)
│   │   │   └── foreground/ (decors.png)
│   │   ├── ruins/
│   │   │   ├── background/ (ruins_background.png)
│   │   │   └── platforms/  (ruins_platform_tiles.png)
│   │   └── desert_temple/
│   │       ├── background/ (temple_walls.png)
│   │       └── platforms/  (temple_platforms.png)
│   ├── sfx/
│   │   ├── attacks/    (20 WAV — sword swings, bow shots, spell casts)
│   │   ├── impacts/    (26 WAV — hits, blocks, parries, spell impacts)
│   │   ├── footsteps/  (40 WAV — chain+unarmored × dirt/stone/wood)
│   │   ├── ambience/   (18 OGG — forest day/night, interior, cave, water)
│   │   └── ui/         (9 WAV — menu_open, menu_close, confirm, back, select)
│   ├── music/          (24 OGG loops — see Stage Audio section below)
│   ├── ui/
│   │   ├── fonts/      (alagard.ttf, Planes_ValMore.ttf)
│   │   ├── hud/        (11 PNGs — health bar assets)
│   │   ├── icons/      (11 PNGs — magic/spell icons)
│   │   └── menus/      (fantasy_ui.png — panels, buttons, controller icons)
│   └── vfx/
│       ├── hit_sparks/ (84 PNGs)
│       ├── magic/      (111 PNGs)
│       ├── ko/         (48 PNGs)
│       └── dust/       (24 PNGs)
├── scenes/
│   ├── characters/
│   ├── stages/
│   └── ui/
├── scripts/
│   ├── characters/
│   ├── stages/
│   ├── ui/
│   └── managers/
└── resources/
```

---

## Sprite Sheet Convention

All character animations are **horizontal strip sprite sheets** (single PNG per animation):
- Each frame is **128×128 pixels**
- The sheet is **128px tall** and **N×128px wide** (where N = frame count)
- Frame count varies per animation — divide sheet width by 128 to get frame count
- Use `Hframes` on a `Sprite2D` or region slicing in `AnimatedSprite2D`

**Standard animation names per character** (actual file names vary by character — list files in their sprites/ folder to discover them):
- `idle`, `run`, `jump`, `fall`, `attack_1`, `attack_2`, `attack_3` (or `special`)
- `hurt`, `death`, `block` (where available)
- Some characters have additional unique animations (e.g., `dash`, `cast`, `shoot`)

---

## Characters

There are 9 characters using 6 distinct scripts, all extending `Character.gd`.
Do not use a generic "Warrior/Wizard/Samurai" class system — each script below
implements its character's actual animations and unique mechanics.

Animation names below are exact filenames (without .png) from each sprites/ folder.

---

### Knight.gd — used by knight_1, knight_2, knight_3

All three knights share this script. They are pure visual variants.

**Animations:** `Idle`, `Walk`, `Run`, `Jump`, `Attack 1`, `Attack 2`, `Attack 3`, `Defend`, `Protect`, `Run+Attack`, `Hurt`, `Dead`

**Mechanics:**
- Light attack → `Attack 1`
- Heavy attack → `Attack 2`
- Attack 3 → third hit in manual combo chain (press heavy again after heavy)
- `Run+Attack` → play this animation when attack input is pressed while in RUN state
- `Defend` → enter when block input held. Reduces incoming damage by 60%.
- `Protect` → brief shield-raise pose played at start of Defend transition
- No special projectile — knights are pure melee

**Stats:** HP 150, Speed 200, Jump -550, Light damage 12, Heavy damage 22

---

### Samurai.gd — used by samurai, samurai_commander

**Animations:** `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Attack_3`, `Protection` (samurai) / `Protect` (samurai_commander), `Hurt`, `Dead`

Note: samurai uses `Protection`, samurai_commander uses `Protect` — detect which
file exists in the character's sprites/ folder and use the correct name.

**Mechanics:**
- Light attack → `Attack_1`
- Heavy attack → `Attack_2`
- Special → `Attack_3`: fast multi-hit dash forward (moves character 80px forward
  over the animation duration, hits up to 3 times for 6 damage each)
- Block → `Protection`/`Protect`: same as knight Defend — reduces damage 60%

**Stats:** HP 120, Speed 260, Jump -580, Light damage 10, Heavy damage 18

---

### SamuraiArcher.gd — used by samurai_archer only

**Animations:** `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Attack_3`, `Shot`, `Arrow`, `Hurt`, `Dead`

**Mechanics:**
- Light attack → `Attack_1` (fast melee slash)
- Heavy attack → `Attack_2` (slower melee)
- Attack_3 → melee combo finisher
- Special → `Shot`: plays Shot animation, spawns an Arrow projectile using the
  `Arrow` sprite. Arrow travels at 600px/s, deals 14 damage on contact, despawns
  after 1000px or on hit. Can fire in midair.
- No block animation — most mobile character, avoidance over defense

**Stats:** HP 110, Speed 280, Jump -600, Light damage 9, Heavy damage 16, Arrow damage 14

---

### FireWizard.gd — used by fire_wizard only

**Animations:** `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Charge`, `Fireball`, `Flame_jet`, `Hurt`, `Dead`

**Mechanics:** (Phase 8: dropped the tap/hold duration design in favor of two separate inputs — C and V)
- Light attack → `Attack_1` (close melee swipe)
- Heavy attack → `Attack_2` (slower melee)
- Special (C) → `Fireball` cast animation, spawns `Fireball_projectile.png` at
  450px/s, deals 18 damage, despawns after 900px or on hit. Plays magic VFX
  on spawn and impact.
- Special 2 (V) → `Flame_jet`: sustained AOE for 1 second. Implementation
  activates `hitbox_light` for 1 second and deals 8 damage per 0.2s tick
  (max 40 total). No extra VFX layered on top of the jet animation.

**Stats:** HP 100, Speed 220, Jump -600, Light damage 8, Heavy damage 14

---

### LightningMage.gd — used by lightning_mage only

**Animations:** `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Charge`, `Light_charge`, `Light_ball`, `Hurt`, `Dead`

**Mechanics:** (Phase 8: dropped the tap/hold duration design. V was also re-scoped from a slow large projectile to a charged melee AOE — the Light_charge animation is visually a close-range burst, not a projectile wind-up.)
- Light attack → `Attack_1`
- Heavy attack → `Attack_2`
- Special (C) → `Light_ball` cast → spawns `Light_ball_projectile.png` at
  500px/s, deals 12 damage, radius ~18px
- Special 2 (V) → `Light_charge` animation → activates `hitbox_heavy` during
  active frames (frame 1 through total-2) for a charged melee strike dealing
  28 damage with 1 second of extra hitstun on hit. Not a projectile.
  Overrides `_on_sprite_frame_changed()` to gate the hitbox window and
  `_on_hitbox_heavy_area_entered()` to apply the extra hitstun.

**Stats:** HP 100, Speed 215, Jump -600, Light damage 8, Heavy damage 14

---

### WandererMagician.gd — used by wanderer_magician only

**Animations:** `Idle`, `Walk`, `Run`, `Jump`, `Attack_1`, `Attack_2`, `Charge_1`, `Charge_2`, `Magic_arrow`, `Magic_sphere`, `Hurt`, `Dead`

**Mechanics:** (Phase 8: two-input model — C and V, as with the other wizards)
- Light attack → `Attack_1`
- Heavy attack → `Attack_2`
- Special (C) → `Magic_arrow` cast → spawns `Magic_arrow_projectile.png` at
  550px/s, deals 10 damage, rectangular hitbox, 0.25s cooldown — can fire
  quickly in succession.
- Special 2 (V) → `Magic_sphere` cast → spawns `Magic_sphere_projectile.png`
  at 250px/s, deals 22 damage, circular hitbox, pierces (does not despawn on
  first hit).

**Stats:** HP 105, Speed 225, Jump -595, Light damage 9, Heavy damage 15

---

## Game Mechanics

### Core Loop
1. Players select characters on the character select screen
2. Players select (or random-pick) a stage
3. 3-stock match: each player starts with 3 lives
4. When HP hits 0, a player loses a stock and respawns at center top
5. Last player with stocks remaining wins
6. Win screen → rematch or return to menu

### Movement
- Left/right movement with acceleration and friction (not instant)
- Single jump + one double jump (coyote time: 6 frames)
- Fast fall (hold down while airborne)
- Wall slide (slow fall when pressed against wall)
- Dash (double-tap direction, or L1/LB on controller)

### Combat
- **Light attack** (X button / Z key): Fast, low damage, low knockback
- **Heavy attack** (Y button / X key on keyboard): Slow startup, high damage, high knockback
- **Special attack** (B button / C key): Character-specific — see each character's spec in the Characters section. Mechanics vary significantly: knights have no special, samurai dash attacks, archer fires arrows, wizards have tap vs. hold charge variants with different projectiles
- **Block/Shield** (L trigger / left shift): Reduces incoming damage by 60%, cannot move while blocking
- Attacks have 3 phases: startup frames (no hitbox), active frames (hitbox live), recovery frames (vulnerable)
- **Hitstun:** Receiving a hit freezes the character briefly (5–12 frames depending on attack weight)
- **Knockback:** Fixed impulse velocity per attack type — does NOT scale with accumulated damage. Use these tuned values (horizontal component only; vertical is handled separately):
  ```gdscript
  var kb_base := 350.0 if is_heavy else 200.0
  var direction = sign(target.position.x - attacker_pos.x)
  velocity = Vector2(direction * kb_base, -200.0 if is_heavy else -120.0)
  ```
  Knockback creates spacing pressure and edge danger but is never the primary kill condition.

### Death & Stock System — HP BASED, NOT SMASH STYLE
**This is not a Smash Bros damage percentage system. Do not implement percentage-based knockback scaling.**

- Each character has a `current_hp` and `max_hp`. Attacks subtract flat damage values directly from `current_hp`.
- **Primary death condition:** `current_hp <= 0` → triggers `die()`
- **Secondary death condition:** character enters a kill zone (fell off stage) → also triggers `die()`
- Both conditions decrement stocks identically.
- On death: play KO VFX, decrement stock, respawn at spawn point after 1.5 seconds with 2 seconds of invincibility.
- When stocks reach 0: player eliminated, match ends.
- There is NO damage percentage accumulator. NO knockback scaling formula. Knockback values are fixed constants defined per attack type.

### Death & Respawn — Required Ordering (learned in Phase 6)

The following ordering rules must be preserved in `die()` and `respawn()`. Each exists to prevent a specific bug that shipped to Phase 6 before being fixed:

1. **`die()` must set `change_state(State.DEAD)` on its very first line**, immediately after the `if state == State.DEAD: return` guard. Two overlapping kill zones (e.g., `KillBottom` + `KillLeft` at a corner) can fire `body_entered` in the same physics frame; the DEAD flag is what blocks the second callback from double-decrementing stocks.
2. **In `respawn()`, teleport to `respawn_position` BEFORE setting `process_mode = PROCESS_MODE_DISABLED`.** If the body is frozen while still inside a kill zone, re-enabling it triggers `body_entered` again for the same zone. Teleport first, then disable.
3. **BattleScene's `_on_kill_zone_entered()` must also check `character.is_invincible`** — post-respawn i-frames are what block the kill zone from refiring during the 2-second invincibility window.
4. **Snap `current_hp` to 0.0 when it drops below 1.0** after damage subtraction. Floating-point remainders leave a tiny positive HP value that the progress bar still renders as non-zero, causing visible desync between "character died" and "bar empty".
5. **Exit HURT state from `_tick_timers()`, not from `animation_finished`.** The hurt animation can end a few ms before the hitstun timer, leaving the state machine stuck. Always drive HURT exit from the timer.
6. **Do NOT call `VFXManager` or `AudioManager` from `die()` until Phase 7.** Those managers are stubs until then and a silent nil-call can mask other errors.

### Hitboxes / Hurtboxes
- Use `Area2D` nodes for hitboxes (attack zones) and hurtboxes (damageable zones)
- Collision layers (match Phase 1 setup exactly):
  - Layer 1: CharacterBody2D world/platform collision
  - Layer 2: Hurtboxes (`collision_layer = 2`)
  - Layer 4: Hitboxes (`collision_layer = 4`, `collision_mask = 2`) — hitboxes scan for hurtboxes only
  - Layer 8: Kill zones (`collision_layer = 8`)
- Hitboxes activate via `_on_sprite_frame_changed()` signal and only while in attack state
- Characters are immune during respawn (2-second invincibility)

---

## Input System

### InputMap Actions (define in Project Settings → Input Map)
All actions must support both keyboard AND controller. **No numpad keys are used anywhere in the project** — numpad layout was dropped in Phase 8 in favor of the right-hand cluster below so laptops without numpads stay playable.

| Action | Player 1 Keyboard | Player 2 Keyboard | Controller (both players) |
|--------|------------------|------------------|--------------------------|
| `p{n}_left` | A | Left Arrow | Left Stick Left / DPad Left |
| `p{n}_right` | D | Right Arrow | Left Stick Right / DPad Right |
| `p{n}_up` | W | Up Arrow | Left Stick Up / DPad Up |
| `p{n}_down` | S | Down Arrow | Left Stick Down / DPad Down |
| `p{n}_jump` | Space | `/` | A (Xbox) / Cross (PS) |
| `p{n}_light_attack` | Z | `,` | Right Stick Right |
| `p{n}_heavy_attack` | X | `.` | Right Stick Left |
| `p{n}_special` | C | `'` | Right Stick Up |
| `p{n}_special2` | V | `;` | Right Stick Down |

Where `{n}` = 1 or 2. Use `device` parameter on InputEvents to differentiate controllers.

**Controller attack scheme (post-Phase 8 revision):** All four attack actions are bound exclusively to right stick directions. Block and dash controller bindings were removed — the unified scheme is: move with left stick/DPad, jump with A/Cross, and all four attacks with right stick directions. There are no face button, shoulder button, or trigger bindings for attacks.

**About `p{n}_special2`:** Phase 8 added a second special-attack input for wizards (Fire Wizard, Lightning Mage, Wanderer Magician). The original design used hold-duration on the main special button to switch between two variants — that was dropped. Each wizard now has two completely separate inputs: `special` fires the tap-style cast, `special2` fires the heavy/hold-style cast. See each wizard's spec in the Characters section for which ability goes on which input. `InputManager.is_special2_pressed(player_id)` is the lookup. The base `Character.gd.special2_attack()` is a no-op; wizard scripts override it.

### Controller Detection
- Detect connected controllers with `Input.get_connected_joypads()`
- Player 1 = joypad device 0 (or keyboard fallback)
- Player 2 = joypad device 1 (or keyboard fallback)
- Show controller icon prompts using the controller icons in `assets/ui/menus/fantasy_ui.png`

---

## Stages

## Stage Layout Philosophy


**Critical implementation note — platforms must tile, not stretch:**
Never scale a single Sprite2D to make a wide platform. This breaks the visual texture. Instead:
- Use a `TileMap` node with the platform texture sliced into tiles (typically 16×16 or 32×32 per tile) so the texture repeats naturally across the platform's width
- Or use multiple fixed-size Sprite2D nodes placed edge-to-edge to span the platform width

**TileMap is VISUAL ONLY — all collision uses StaticBody2D:**
Do NOT enable physics layers on the TileMap. All platform collision must be implemented as separate `StaticBody2D` nodes with `RectangleShape2D` sub-resources, placed to match the visual tile layout. This separation keeps physics predictable and independent of the visual tile grid.

---

### Stage 1: Windrise
**Theme:** Lush green meadow, rolling hills, open sky — bright and airy

**Visual layers:**
1. Background: `windrise-background.png` — full sky/horizon scene (parallax 0.2)
2. Midground: `mountains.png` — distant mountain range (parallax 0.5)
3. Foreground hills: `hills.png` — rolling hills in front of mountains (parallax 0.8)
4. Platforms: built from `floating_platforms.png` using TileMap (parallax 1.0)
5. Foreground decor: `decors.png` — no collision, parallax 1.2

**Music:** Randomly pick from Prairie_3, Prairie_4, Prairie_5, BattleField_1–5, EpicBattle
**Ambience:** `forest_day` OGG at low volume under music

---

### Stage 2: Ruins
**Theme:** Lush green overgrown ruins, floating castles in stormy sky, outdoor
**Note:** This stage was previously called "dungeon" — all references to dungeon in scenes/scripts should use "ruins" instead. The old dungeon_.png and terrain_tiles.png assets are superseded and should be ignored.

**Visual layers:**
1. Background: `ruins_background.png` — full scene background, lush green valley with floating castles
2. Platforms: built from `ruins_platform_tiles.png` tileset

**Platform tileset — `ruins_platform_tiles.png` categories:**
- **Ground & Cliff Tiles** (top-left section of sheet): use these for the two main ground sections
- **Floating Island Tiles** (top-right section): pre-built floating island pieces — use for the three floating platforms above the gap
- **Ruin Tiles**: columns, pillars — decorative on ground sections
- **Stair Tiles**: for edges of ground sections
- **Decor & Props**: trees, torches, arch — place on ground sections for visual interest
- **Spike Tiles**: place at bottom of gap as a hazard visual (kill zone is still an Area2D, spikes are decoration)
- The tileset has no explicit pixel grid label — detect tile size from the image and slice accordingly

use the reference image to determin platform layout

**Music:** Randomly pick from Gothic_Dark, Demise, Havoc, Fight_1–3, Crisis
**Ambience:** `cave` or `interior` OGG

---

### Stage 3: Desert Temple
**Theme:** Sandy desert ruins, warm golden tones, ancient and open
**Note:** Old `temple_walls.png` and `temple_platforms.png` are superseded by the new dedicated assets below.

**Visual layers:**
1. Background: `desert_background.png` — full desert scene with oasis and dunes
2. Platforms: sliced from `desert_platforms.png` asset sheet

**Platform asset sheet — `desert_platforms.png` (256×256 grid):**
The sheet is labeled with named pieces. Slice on a 256×256 grid and use pieces by name:
- `PLAT_MAIN_L` — left ground section piece
- `PLAT_MAIN_H` — right/heavy ground section piece  
- `PLAT_MAIN_C` — center ground section with pillar detail (use for decorating gap edge)
- `FLOAT_ISL_C` — large center floating island with pillars and flag (center float)
- `FLOAT_ISL_0` — medium floating island (left float)
- `FLOAT_ISL_1` — small floating island (right float or top center)
- `BROKEN_ARK` — broken arch, decorative
- `PILLAR_L1`, `PILLAR_L0`, `PILLAR_L0_2`, `PILLAR_L0_3` — pillar variants for ground decoration
- `FLAG_A` — flag prop
- Cave arch at bottom center — visual detail for gap area

**Platform layout:**

use the reference image to determine platform layout

**Music:** Randomly pick from Raid_Ethnic, Raid_FolkMetal_1–2, Raid_1–3, Flap_1–2
**Ambience:** `water` or `forest_night` OGG

---

## VFX System

**IMPORTANT — asset format correction (verified in Phase 7):**
VFX PNGs are NOT individual frames. Each PNG is a sprite sheet. For the 576px-tall sheets (`hit_sparks`, `ko`, `dust`, most of `magic`) the sheet is a 9-row grid of 64×64 cells, where **each row is one complete animation**. For the 72px-tall sheets in `magic/`, the sheet is a single horizontal strip of 72×72 frames. Frame size is detected from the sheet height — 576px → 64×64 × 9 rows; 72px → 72×72 × 1 row.

Do NOT load `DirAccess.get_files_at("res://assets/vfx/hit_sparks/")` and treat each PNG as a frame — that will render a 768×576 block across the screen. The VFXManager implemented in Phase 7 slices every PNG into per-row animations.

| Folder | Usage | Trigger | Sheet count |
|--------|-------|---------|-------------|
| `vfx/hit_sparks/` | Melee impact flash | On successful light/heavy hit | 84 sheets × 9 rows = 756 animations |
| `vfx/magic/` | Spell effects, projectile bodies, explosions | Wizard specials, magic impacts | mixed 64×64 and 72×72 strips |
| `vfx/ko/` | Knockout explosion, star burst | When a player loses a stock | 48 sheets × 9 rows = 432 animations |
| `vfx/dust/` | (unused — landing VFX removed in Phase 7) | — | 24 sheets × 9 rows = 216 animations |

**VFXManager API (implemented in Phase 7):**
- `VFXManager.play(type, position, scale, anim_idx)` — spawns a full `AnimatedSprite2D`, plays one row as an animation, auto-frees on `animation_finished`
- `VFXManager.play_single(type, position, scale, duration, anim_idx)` — spawns a `Sprite2D` with one random frame from a row, frees after `duration` seconds (used for impact flashes so they don't loop)
- `VFXManager.get_anim_count(type)` — number of animations loaded for that type
- `anim_idx = -1` → random animation; `anim_idx >= 0` → pin to a specific row
- `anim_idx` formula for pinning a specific sheet+row: `(sheet_number_0indexed * 9) + row_number_0indexed`

### Pinned VFX Selections (reuse these exact calls across all characters)

| Effect | Call | Purpose |
|--------|------|---------|
| Melee hit connect | `VFXManager.play_single("hit_sparks", hit_position, 2.0, 0.12, 618)` | Steel/grey claw burst (sheet `881.png` row 6) |
| KO / stock loss | `VFXManager.play("ko", global_position, 2.0, 19)` | Purple starburst swirl (sheet `1103.png` row 1) |

All melee characters in Phase 8 should reuse these pinned calls so VFX is consistent across the roster. Wizards/archer will add magic VFX for projectile spawns — pin those during Phase 8 using the same workflow.

### VFX Pinning Workflow (how to pick a specific anim_idx)
1. Open `assets/vfx/<type>/` in Finder, arrow-key through PNGs until you find one you like
2. Note the filename and the row number (0-indexed from the top of the sheet)
3. Run `ls assets/vfx/<type>/*.png | sort | grep -n "<filename>"` to get the 1-indexed line number
4. `anim_idx = (line_number - 1) * 9 + row`
5. Pass as the last argument to `play()` or `play_single()`

### Landing / State-Transition VFX Gotcha
`is_on_floor()` flickers rapidly as a character runs across TileMap tile-edge seams. A naive "spawn VFX on landing" hook triggered hundreds of overlapping animations within seconds of gameplay during Phase 7. If any future phase adds a landing / state-transition VFX, guard it with a state check — e.g., only fire when `state == State.JUMP or state == State.FALL` at the moment of floor contact — so tile-edge jitter doesn't register as a landing. (Dust-on-landing was tried and removed in Phase 7; listed here so the same mistake isn't repeated.)

---

## Projectile Asset Conventions (learned in Phase 8)

### Filename rule — `*_projectile.png` is the FLYING sprite
Every wizard/archer has two related PNGs in their sprites folder. They are not interchangeable:

| Filename | What it is |
|----------|------------|
| `Fireball.png`, `Light_ball.png`, `Magic_arrow.png`, `Magic_sphere.png`, `Shot.png` | Cast-pose animation of the character throwing / firing. Used on the character's `AnimatedSprite2D` during the cast. |
| `Fireball_projectile.png`, `Light_ball_projectile.png`, `Magic_arrow_projectile.png`, `Magic_sphere_projectile.png`, `Arrow.png` | The flying projectile itself. Used on the `Projectile.gd` instance's `Sprite2D`. |

Referencing the wrong file is a silent failure with a very visible symptom: the wizard's own cast-pose sprite flies across the screen as the "projectile". Always use the `_projectile` suffix when loading the flying sprite.

### All projectile sheets use 64px-wide frames (no exceptions)
Every flying-projectile sheet in this project uses **64px-wide frames**, regardless of sheet height. Do NOT compute `hframes` from `width / height` — that's wrong for sheets taller than 64px.

| Sheet | Dimensions | Correct hframes | width/height would give |
|-------|-----------|-----------------|-------------------------|
| `Magic_arrow_projectile.png` | 384 × 128 | 6 | 3 (wrong — shows 2 frames side-by-side) |
| `Magic_sphere_projectile.png` | 576 × 128 | 9 | 4.5 |
| `Fireball_projectile.png` | 768 × 64 | 12 | 12 (only correct by coincidence) |
| `Light_ball_projectile.png` | 576 × 64 | 9 | 9 (only correct by coincidence) |

Always: `hframes = int(tex.get_width() / 64.0)`. This formula is canonical for every projectile in the project.

### Sprite2D has no built-in frame playback
`Sprite2D` draws frame 0 by default and does not advance on its own. `Projectile.gd` manually advances `spr.frame = (spr.frame + 1) % spr.hframes` in `_physics_process()` against an `anim_fps` timer. Any new projectile in a future phase must do the same — setting `hframes` and `texture` alone produces a static still image.

### Un-imported PNGs — `_load_raw_texture()` in `Character.gd`
Several `*_projectile.png` assets shipped without Godot `.import` sidecar files, so `load("res://…")` fails with `No loader found for resource`. `Character.gd` exposes a helper:

```gdscript
func _load_raw_texture(res_path: String) -> ImageTexture:
    var img := Image.new()
    img.load(ProjectSettings.globalize_path(res_path))
    return ImageTexture.create_from_image(img)
```

Use it for any PNG that lacks an `.import` sidecar. It works in the editor and `--headless` debug runs but would need a real import pass for an exported build — flag any reliance on it as tech debt when approaching Phase 11.

### `_calc_hframes(tex)` vs the 64px rule
`Character.gd` also has `_calc_hframes(tex)` which returns `width / height`. That's fine for square-frame character sprite sheets (128×128 per frame). It is NOT the right helper for projectiles — always use the explicit `int(tex.get_width() / 64.0)` for projectile sheets, even if the numbers happen to match for a given sheet.

---

## Audio System

### AudioManager (Autoload Singleton — implemented in Phase 7)
```gdscript
# Methods:
# AudioManager.play_sfx(sfx_name)        — prefix-group lookup, picks random variant
# AudioManager.play_music(track_path)    — two-player crossfade over 1s
# AudioManager.play_ambience(amb_path)   — loops OGG on Ambience bus at -12 db
# AudioManager.stop_music()              — fades current music to silence over 1s
# AudioManager.set_volume(category, db)  — "Master", "Music", "SFX", "Ambience"
```

**SFX prefix-group semantics:**
On startup AudioManager loads all WAVs from `sfx/attacks/`, `sfx/footsteps/`, `sfx/impacts/`, `sfx/ui/` and groups them by prefix — any trailing number is stripped. So `Sword Attack 1.wav`, `Sword Attack 2.wav`, `Sword Attack 3.wav` all land in the group `"Sword Attack"`. `play_sfx("Sword Attack")` picks one at random from the group. Lookups are **case-insensitive**.

To inspect available groups at runtime: `print(AudioManager._sfx_groups.keys())`.

**Known working group names (used by knight_1 in Phase 7 — reuse for all melee characters):**
- `"Sword Attack"` — call on `attack_light()` and `attack_heavy()`
- `"Sword Impact Hit"` — call in `_apply_hit` after `take_damage` returns

Wizards/archer will need different groups (spell cast, bow shot, magic impact). Discover group names via the runtime print above during Phase 8.

**Music crossfade:**
`play_music(track_path)` alternates between `_music_a` and `_music_b` AudioStreamPlayers. Each call fades in the inactive player (−80 → 0 db over 1s) and fades out the active one (0 → −80 db over 1s) via separate Tweens. Safe to call mid-match for dynamic music switching.

### Sound Categories & Bus Setup
Create 4 audio buses in Godot (Project → Audio):
- **Master** (default)
- **Music** — volume controllable, for OGG loops
- **SFX** — volume controllable, for WAV one-shots
- **Ambience** — low volume, for OGG ambient loops

### SFX Trigger Map
| Event | SFX to play (pick randomly from group) |
|-------|----------------------------------------|
| Light melee attack swing | `attacks/` — sword_swing variants |
| Ranged/magic attack | `attacks/` — bow_shot or spell_cast variants |
| Hit landed (light) | `impacts/` — hit variants |
| Hit landed (heavy) | `impacts/` — heavy hit variants |
| Block | `impacts/` — block/parry variants |
| Footstep (stone stage) | `footsteps/` — stone variants |
| Footstep (dirt/wood) | `footsteps/` — dirt or wood variants |
| Menu navigate | `ui/select.wav` |
| Menu confirm | `ui/confirm_1.wav` or `confirm_2.wav` |
| Menu back | `ui/back_1.wav` or `back_2.wav` |
| Menu open | `ui/menu_open_1.wav` or `menu_open_2.wav` |

---

## Scene Architecture

### Scene Tree Structure

```
Main (Node)
├── GameManager (Node) — autoload singleton
├── AudioManager (Node) — autoload singleton
├── VFXManager (Node) — autoload singleton
├── InputManager (Node) — autoload singleton
│
├── MainMenu (scenes/ui/MainMenu.tscn)
│   ├── Background
│   ├── TitleText
│   ├── StartButton
│   ├── OptionsButton
│   └── QuitButton
│
├── CharacterSelect (scenes/ui/CharacterSelect.tscn)
│   ├── Player1Panel
│   │   ├── CharacterGrid
│   │   └── PreviewSprite
│   └── Player2Panel
│       ├── CharacterGrid
│       └── PreviewSprite
│
├── StageSelect (scenes/ui/StageSelect.tscn)
│
├── BattleScene (scenes/stages/BattleScene.tscn)
│   ├── Stage (scenes/stages/[stage_name].tscn)
│   │   ├── Background (ParallaxBackground)
│   │   ├── Platforms (StaticBody2D nodes)
│   │   ├── KillZones (Area2D — bottom, left, right, top)
│   │   └── SpawnPoints (Marker2D × 2)
│   ├── Players
│   │   ├── Player1 (scenes/characters/[character].tscn)
│   │   └── Player2 (scenes/characters/[character].tscn)
│   └── HUD (scenes/ui/HUD.tscn)
│       ├── Player1HUD (health bar, stock icons)
│       └── Player2HUD
│
└── WinScreen (scenes/ui/WinScreen.tscn)
```

### Character.tscn — Placeholder Node Invariant (Phase 8)

`Character.tscn` has a `Placeholder` ColorRect child (the blue dev box used during Phase 2). **Do not delete it.** Its removal would shift child indices 4 and 5 — which are `HitboxLight` and `HitboxHeavy` — and break every one of the 9 character `.tscn` files that inherit from `Character.tscn` and reference hitboxes by path/index. The correct fix for visibility is `visible = false` on the Placeholder, which Phase 8 already applied. This is load-bearing invisible scaffolding; treat it as frozen until a future phase reworks the hitbox architecture wholesale.

### BattleScene Boot-Time Character Validation (Phase 8)

`BattleScene._validate_all_characters()` runs at startup, instantiates each of the 9 character scenes, and logs their HP/Speed. On failure it calls `push_error`. Expected console output on a healthy boot:

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

Any future phase that changes stats, renames characters, or restructures the character tscn hierarchy must keep this validation passing — if it breaks, every boot logs an error. Three stale `invalid UID` warnings also appear on every boot; they're non-fatal (Godot falls back to path lookup) and were not worth fixing in Phase 8.

---

## Script Architecture

### Autoload Singletons (Project → Autoload)
- `GameManager` (`scripts/managers/GameManager.gd`) — global game state, selected characters, selected stage, stock counts, match result
- `AudioManager` (`scripts/managers/AudioManager.gd`) — all audio playback
- `VFXManager` (`scripts/managers/VFXManager.gd`) — VFX spawning
- `InputManager` (`scripts/managers/InputManager.gd`) — controller/keyboard abstraction

### Core Scripts

#### `scripts/characters/Character.gd` (base class)
```
extends CharacterBody2D

# Properties
var player_id: int          # 1 or 2
var character_name: String
var max_hp: float
var current_hp: float
var stocks: int = 3
var move_speed: float
var jump_force: float
var is_blocking: bool
var is_attacking: bool
var facing_right: bool = true
var is_invincible: bool = false
var attack_damage_light: float
var attack_damage_heavy: float
var spawn_facing_right: bool = true   # BattleScene sets false for right-side player; respawn() restores this

# State machine
enum State { IDLE, RUN, JUMP, FALL, ATTACK_LIGHT, ATTACK_HEAVY, SPECIAL, 
             HURT, DEAD, BLOCKING, DASHING, WALL_SLIDE }
var state: State = State.IDLE

# Nodes
@onready var sprite: AnimatedSprite2D
@onready var hurtbox: Area2D
@onready var hitbox_light: Area2D
@onready var hitbox_heavy: Area2D
@onready var collision: CollisionShape2D

# Key methods
func _physics_process(delta)   # movement + physics
func handle_input()             # read InputManager for this player_id
func change_state(new_state)   # state machine transitions + animation
func take_damage(amount, knockback_dir, is_heavy)
func die()
func respawn()
func attack_light()
func attack_heavy()
func special_attack()          # override in subclasses
func _on_hurtbox_area_entered(area)  # receive hits
```

#### `scripts/characters/Knight.gd` (extends Character) — knight_1, knight_2, knight_3
- No special projectile. Block mechanic via `Defend`/`Protect` animations.

#### `scripts/characters/Samurai.gd` (extends Character) — samurai, samurai_commander
- Special: dash forward with multi-hit hitbox active (`Attack_3`)

#### `scripts/characters/SamuraiArcher.gd` (extends Character) — samurai_archer
- Special: spawn Arrow projectile using `Shot` animation. No block.

#### `scripts/characters/FireWizard.gd` (extends Character) — fire_wizard
- Special (C): Fireball cast → `Fireball_projectile.png`
- Special 2 (V): Flame_jet sustained AOE via `hitbox_light` for 1s

#### `scripts/characters/LightningMage.gd` (extends Character) — lightning_mage
- Special (C): Light_ball cast → `Light_ball_projectile.png`
- Special 2 (V): Light_charge melee AOE via `hitbox_heavy` (not a projectile — re-scoped in Phase 8)

#### `scripts/characters/WandererMagician.gd` (extends Character) — wanderer_magician
- Special (C): Magic_arrow cast → `Magic_arrow_projectile.png`
- Special 2 (V): Magic_sphere cast → `Magic_sphere_projectile.png` (piercing, does not despawn on first hit)

#### `scripts/characters/Projectile.gd` (extends Area2D) — base projectile
Used by SamuraiArcher Arrow, FireWizard Fireball, LightningMage Light_ball, WandererMagician Magic_arrow and Magic_sphere.
- `collision_layer = 4`, `collision_mask = 3` (scans hurtboxes on layer 2 AND StaticBody2D platforms on layer 1)
- Properties: `speed`, `damage`, `max_distance`, `is_piercing`, `owner_id`, `extra_hitstun`
- Animates manually: `_physics_process()` advances `Sprite2D.frame = (frame + 1) % hframes` on an `anim_fps` timer because `Sprite2D` has no built-in playback
- `area_entered` → `take_damage()` on the hit character, applies `extra_hitstun` if set, plays hit VFX/SFX, then `queue_free()` unless `is_piercing = true`
- `body_entered` → `queue_free()` ONLY when `body is StaticBody2D` — filtering is required because character `CharacterBody2D` is also on layer 1 and would otherwise trigger a false despawn

#### `scripts/managers/GameManager.gd`
```
# Tracks:
var p1_character: String
var p2_character: String
var selected_stage: String
var p1_stocks: int
var p2_stocks: int
var match_active: bool

# Signals:
signal stock_lost(player_id)
signal match_ended(winner_id)

# Methods:
func start_match()
func on_player_death(player_id)
func end_match()
func go_to_character_select()
func go_to_stage_select()
func go_to_battle()
```

#### `scripts/ui/HUD.gd`
- Reads from GameManager signals for stock count
- Updates health bars by polling Character.current_hp / Character.max_hp each frame
- Health bar uses `greenbar_1.png` / `redblue_1.png` assets stretched via `ProgressBar` or custom shader

---

## HUD Design

Use assets from `assets/ui/hud/`:
- `HealthBar DARK.png` — outer frame/container for health bar
- `greenbar_1/2/3.png` — fill texture (green = healthy, swap to redblue at low HP)
- `redblue_1/2/3.png` — alternate fill for player 2 or low health warning
- `rpg_1/2/3.png` — stock life icons (display 3 per player, grey out lost stocks)
- `Darkupdate.png` — HUD background panel

Layout: Player 1 HUD bottom-left, Player 2 HUD bottom-right (mirrored).

### HUD Architecture Notes (from Phase 6 build)

**HUD wiring pattern — no dynamic node creation:**
`HUD.gd` contains pure runtime logic. All visual nodes (health bars, hearts, borders) are real scene nodes in `HUD.tscn` and editable in the Godot editor. Character references are injected via `HUD.set_characters(p1, p2)` called from `BattleScene._ready()` after spawn points assign their player references. HUD polls `current_hp / max_hp` each `_process` frame for the bar and connects to `GameManager.stock_lost` (signal) for heart greying — do NOT poll stocks every frame.

**Low-HP color swap threshold:** below 25% HP, swap the `TextureProgressBar` fill from `greenbar_1.png` to `redblue_1.png`. Use `nine_patch_stretch = true` so the texture scales cleanly at any bar width.

**Trough and border — use ColorRect + Panel, not StyleBoxEmpty:**
Godot 4's scene serializer silently discards `StyleBoxEmpty` sub-resources on save. If you need a transparent background for a Panel, it will revert to the default style next time the scene loads. Instead:
- Dark maroon trough behind the bar: use a sibling `ColorRect` with `show_behind_parent = true`
- Border frame around the bar: use a `Panel` with a `StyleBoxFlat` that has `draw_center = false` (this one does persist)

**Heart/stock icon generation — procedural pixel art:**
`alagard.ttf` does not contain a ♥ glyph, so Label-based hearts silently fall back to the system font and render as squares or wrong glyphs. Always build heart icons as `TextureRect` nodes with a texture generated in code:
```gdscript
func _create_heart_texture() -> ImageTexture:
    var pattern = [[0,1,1,0,1,1,0], [1,1,1,1,1,1,1], ...]
    var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
    for y in 7:
        for x in 7:
            img.set_pixel(x, y, color_for_pixel(pattern[y][x], x, y))
    return ImageTexture.create_from_image(img)
```
Apply `TEXTURE_FILTER_NEAREST` and `stretch_mode = KEEP_ASPECT_CENTERED` so the 7×7 source stays crisp when scaled up to HUD size (e.g., 21×21 at 3×).

**Heart depletion ordering — sort by position.x, never by node name:**
Node names in `.tscn` files are not guaranteed to reflect spatial order. Sort the heart array by `position.x` in `_ready()` so index 0 is always leftmost:
```gdscript
rects.sort_custom(func(a, b): return (a as Control).position.x < (b as Control).position.x)
```
Unified depletion formula for both players: `grey_idx = 2 - remaining` (so P1 loses rightmost first, P2 loses rightmost first — if you want mirror behavior, reverse the sorted array for P2 only).

**Spawn facing direction convention:**
Each Character has `spawn_facing_right: bool = true`. In `BattleScene._ready()`, set `player2.spawn_facing_right = false` alongside the initial `_set_facing(false)` call. `respawn()` then automatically calls `_set_facing(spawn_facing_right)` — no per-player respawn logic needed in the scene controller. Apply this same convention to every character scene in Phase 8.

---

## Menu UI Design

Use `assets/ui/menus/fantasy_ui.png` (sprite sheet — slice as needed):
- **Panels** (3 styles: teal, peach, dark red): menu backgrounds, selection boxes
- **Buttons**: navigation options
- **Controller icons**: show button prompts for current input device
- **Fonts**: use `alagard.ttf` for titles (large, decorative), `Planes_ValMore.ttf` for body text

---

## Development Build Order

Work through these phases in order. Each phase should result in a runnable, testable game state.

---

### Phase 1: Project Initialization
1. Create `project.godot` via Godot MCP or manually — set up 2D project, 1280×720 resolution, pixel art rendering (no anti-aliasing, integer scaling)
2. Set stretch mode: `canvas_items`, aspect: `keep`
3. Configure audio buses: Master, Music, SFX, Ambience
4. Set up collision layers:
   - Layer 1: CharacterBody2D (world/platform collision)
   - Layer 2: Player Hurtboxes (Area2D, `collision_layer = 2`)
   - Layer 4: Attack Hitboxes (Area2D, `collision_layer = 4`, `collision_mask = 2`)
   - Layer 8: Kill Zones (Area2D, `collision_layer = 8`)
5. Add all 4 autoload singletons (GameManager, AudioManager, VFXManager, InputManager) with stub scripts
6. Configure InputMap with all `p1_` and `p2_` actions for keyboard + controller

---

### Phase 2: Base Character Scene
1. Create `scenes/characters/Character.tscn`:
   - Root: `CharacterBody2D`
   - Children: `AnimatedSprite2D`, `CollisionShape2D` (capsule, ~32×64px), `Area2D` (hurtbox) with `CollisionShape2D`, `Area2D` (hitbox_light), `Area2D` (hitbox_heavy)
2. Write `scripts/characters/Character.gd` with:
   - Gravity (800 px/s²)
   - Horizontal movement with friction
   - Jump (with double jump tracking)
   - Basic state machine (IDLE, RUN, JUMP, FALL)
   - Sprite flip on direction change
3. Test with a placeholder colored rectangle — verify movement feels good before adding sprites

---

### Phase 3: One Playable Character (knight_1)
1. Load all sprite sheets from `assets/characters/warriors/knight_1/sprites/`
2. Create `AnimatedSprite2D` SpriteFrames resource — for each PNG:
   - Detect frame count (image width / 128)
   - Add animation with correct frame slicing (128×128 per frame)
   - Set FPS per animation (idle: 8fps, run: 12fps, attack: 16fps, hurt: 10fps, death: 8fps)
3. Wire animation names to Character state machine
4. Implement `attack_light()` and `attack_heavy()`:
   - Enable hitbox Area2D during active frames
   - Disable outside active frames
   - Use `animation_looped` or frame-count tracking
5. Implement `take_damage()` and `die()`
6. Create `scripts/characters/Knight.gd` extending `Character.gd` — wire shield block using `Defend`/`Protect` animations per the Knight spec in the Characters section

---

### Phase 4: First Stage (Windrise) — REQUIRES RETROACTIVE FIX IF ALREADY BUILT
If Windrise.tscn already exists, rebuild the platform layout entirely using these rules:

**Platform implementation — follow the Platform Building Protocol in full:**
- Read and follow the Platform Building Protocol section before writing any platform code
- Measure floating_platforms.png tile size first, log it, then build the TileSet
- Build one section at a time with a screenshot after each — do not build all platforms then screenshot
- Seamless visuals are the acceptance criteria, not pixel-perfect matching of the reference image

**Scene setup:**
1. Create/rebuild `scenes/stages/Windrise.tscn`
2. `ParallaxBackground` with three layers: `windrise-background.png` at 0.2, `mountains.png` at 0.5, `hills.png` at 0.8
3. `TileMap` with `floating_platforms.png` as TileSet — paint the standard layout:
   - Left ground section: x 0–480, y 460–600
   - Right ground section: x 800–1280, y 460–600
   - Left float: x 260–530, y 310
   - Right float: x 750–1020, y 310
   - Top center: x 530–750, y 160
4. `decors.png` as foreground Sprite2D (no collision, parallax 1.2)
5. Kill zones: bottom Y > 750, left X < -150, right X > 1430, top Y < -200
6. Two `Marker2D` spawn points: left (240, 400), right (1040, 400)
7. `BattleScene.tscn` — instantiate Windrise, spawn two knight_1 instances at spawn points

After building, take a screenshot and assess: do the platform sections look visually seamless? Do the ground sections have real visual weight? Adjust tile placement until it looks correct.

---

### Phase 5: Combat System — HP BASED
**Do not implement Smash-style damage percentage scaling. See Combat section above.**

1. Implement hitbox → hurtbox collision:
   - `area_entered` signal on hurtbox → `target.take_damage(amount, attacker_position, is_heavy)`
2. `take_damage(amount, attacker_pos, is_heavy)`:
   - Subtract `amount` from `current_hp`
   - Calculate knockback direction from `attacker_pos` relative to target
   - Apply fixed knockback impulse: light = `Vector2(±180, -120)`, heavy = `Vector2(±320, -200)`
   - Enter HURT state for hitstun duration (light: 5 frames, heavy: 12 frames)
   - If `current_hp <= 0`: call `die()`
3. `die()`: play KO VFX, decrement stock, disable character, respawn after 1.5s with 2s i-frames
4. Kill zone `body_entered` signal also calls `die()` on the entering character
5. `GameManager` tracks stocks for both players, emits `match_ended(winner_id)` when one reaches 0
6. Add 0.1s screen freeze on heavy hit landing

---

### Phase 6: HUD
1. Create `scenes/ui/HUD.tscn`
2. Add health bars using `HealthBar DARK.png` as frame and a `TextureProgressBar` with `greenbar_1.png` as fill
3. Add stock icons (3 × `rpg_1.png` per player, modulate grey when lost)
4. Connect to `GameManager` signals for stock changes
5. Animate health bar on damage (brief flash/shake)

---

### Phase 7: VFX & Audio Integration — COMPLETE
Implemented and verified. Concrete shape (see VFX System and Audio System sections for full detail):
1. `VFXManager` autoload slices each PNG sheet into per-row 64×64 (or 72×72) animations. Exposes `play()`, `play_single()`, `get_anim_count()`. Pinned selections: `hit_sparks` anim_idx 618, `ko` anim_idx 19, both at scale 2.0.
2. `AudioManager` autoload preloads 48 SFX groups, crossfades music via `_music_a`/`_music_b`, loops ambience at −12 db.
3. Knight1 wired: `"Sword Attack"` on attack start, `"Sword Impact Hit"` + hit_sparks on connect, KO VFX in `die()` after `GameManager.on_player_death`. Dust-on-landing was tried and removed.
4. BattleScene plays a random Windrise track + `Forest Day.ogg` ambience on `_ready()`.

---

### Phase 8: All 9 Characters — COMPLETE
All 9 characters implemented using the 6-script model, with VFX/audio wired per character. `Projectile.gd` base class handles all wizard/archer projectiles. Key outcomes and changes of direction:

- Wizards dropped the tap-vs-hold duration design in favor of a separate `p{n}_special2` input (V / `;`). Each wizard's two abilities are now bound to two distinct inputs. See the Input System and Characters sections.
- LightningMage's "V" ability was re-scoped from a large slow projectile to a charged melee AOE via `hitbox_heavy`.
- `Projectile.gd` scans layers 1+2 (platforms AND hurtboxes) and filters `body_entered` to `StaticBody2D` only — characters would otherwise despawn their own projectiles.
- All `*_projectile.png` sheets use 64px-wide frames (see Projectile Asset Conventions).
- `Character.tscn` Placeholder ColorRect is kept with `visible = false` to preserve child-index ordering.
- `BattleScene._validate_all_characters()` runs at boot and logs HP/Speed for all 9.

---

### Phase 9: All 3 Stages
Repeat Phase 4 for Ruins and Desert Temple:
- `scenes/stages/Ruins.tscn` (was previously Dungeon — use ruins assets, not dungeon assets)
- `scenes/stages/DesertTemple.tscn`

Each with correct parallax layers, platform layouts, spawn points, and kill zones as described in Stages section.

---

### Phase 10: Menu Flow
1. **MainMenu.tscn** — title screen with Start, Options, Quit
2. **CharacterSelect.tscn**:
   - 3×3 grid showing all 9 characters
   - Player 1 and Player 2 select independently using their input bindings
   - Preview idle animation on hover
   - Both players press confirm to lock in
3. **StageSelect.tscn**:
   - Show 3 stage thumbnails (screenshot or background image)
   - Player 1 selects, or press random
4. **WinScreen.tscn**:
   - "PLAYER X WINS" with winner's character animation
   - Rematch button / Return to menu button
5. Wire full scene flow: MainMenu → CharacterSelect → StageSelect → BattleScene → WinScreen → loop

---

### Phase 11: Polish
1. Add screen shake on heavy hits (Camera2D with tween offset)
2. Add respawn animation (character fades in from above)
3. Add match countdown (3... 2... 1... FIGHT! overlay)
4. Add options menu: volume sliders for Music/SFX/Ambience, controller mapping display
5. Tune character stats — playtesting adjustments
6. Add winning jingle / losing sound on match end
7. Ensure all audio/VFX are wired and nothing plays from wrong stage
8. Test on macOS: verify controller detection, input mapping, display scaling

---

## Technical Notes

### macOS Compatibility
- Godot 4 exports natively to macOS — no special flags needed
- Use `ProjectSettings.globalize_path()` when constructing asset paths
- Test controller input with both Xbox and generic HID controllers
- Export settings: macOS arm64 + x86_64 universal binary

### Pixel Art Rendering
In Project Settings:
- `rendering/textures/canvas_textures/default_texture_filter` = `0` (Nearest)
- This prevents blurry sprites — critical for pixel art assets

### Performance
- Use `CanvasLayer` for HUD so it doesn't scroll with the camera
- Stream music from disk (OGG files are streamed by default in Godot)
- Preload SFX (WAV) at game start — they're small enough to keep in memory
- VFX nodes: pool and reuse rather than instantiate/free if frame rate drops

### Sprite Art Offset — MUST DO FOR EVERY CHARACTER

Character sprite art is rarely centered in the 128×128 frame. The body often sits left or right of the frame center. If you set `AnimatedSprite2D.position = Vector2(0, 0)`, `flip_h` will mirror around the node origin and the character's visual body will appear to jump horizontally when changing direction.

**For every character, measure the body center before placing the sprite:**
```gdscript
# The formula:
# x_offset = 64 - body_center_pixel_x   (positive = body is left of center)
# y_offset = -(capsule_height / 2 - feet_margin)  (align feet to capsule bottom)

# Known working values for knight_1 (as of Phase 6):
# AnimatedSprite2D position = Vector2(16, -26)
# → 16px right because body center is at ~48px (16px left of 64px center)
# → -26px up to align feet to sit on top of grass (was -16, which caused
#   ~10px of ground clipping; adjusted after HUD work made clipping visible)
```
When building each character in Phase 8, run the game with a test position, observe if the sprite jumps on direction change, and adjust `position.x` until it stays visually stable. Set `position.y` so the feet touch the ground (bottom of capsule at `center_y + capsule_height/2`).

### CapsuleShape2D Height Convention

In Godot 4, `CapsuleShape2D.height` is **total height including both hemisphere caps**, not the half-extent. A capsule with `height = 64` extends from `center_y - 32` to `center_y + 32`.

This is critical for hitbox positioning: if you place a hitbox at `y = -50` expecting it to be "above center", you may be placing it above the top of the enemy's hurtbox entirely. Place hitboxes at torso level relative to the capsule center — approximately `y = -10` works for a standard 64px capsule.

### GDScript 4.6 Gotchas (learned in Phase 7)

**Integer division warning cannot be `@warning_ignore`'d reliably:**
```gdscript
# BAD — emits "Integer division. Decimal part will be discarded." even with
# @warning_ignore annotations and explicit int type declarations:
var cols: int = sheet_width / frame_size

# GOOD — cast through float, then back to int. Same result, no warning:
var cols := int(sheet_width / float(frame_size))
```

**Do not name a function parameter `name`:**
`Node.name` exists on every Node. Using `name` as a parameter in a method on a Node-derived class shadows it and emits a warning. Always namespace parameters (`sfx_name`, `track_name`, `effect_name`, etc.).

### File Loading Pattern
When loading sprite sheets dynamically (e.g., in CharacterSelect previews):
```gdscript
var texture = load("res://assets/characters/warriors/knight_1/sprites/idle.png")
sprite.texture = texture
sprite.hframes = texture.get_width() / 128
sprite.vframes = 1
```

---

## Asset Naming Quick Reference

### Characters — discover animation names by listing their sprites/ folder
```gdscript
var anim_files = DirAccess.get_files_at("res://assets/characters/warriors/knight_1/sprites/")
# Each file = one animation. Strip .png extension for animation name.
```

### Music Files (in assets/music/)
Windrise stage: Prairie_3.ogg, Prairie_4.ogg, Prairie_5.ogg, BattleField_1.ogg through BattleField_5.ogg, EpicBattle.ogg  
Ruins stage: Gothic_Dark.ogg, Demise.ogg, Havoc.ogg, Fight_1.ogg through Fight_3.ogg, Crisis.ogg  
Desert Temple: Raid_Ethnic.ogg, Raid_FolkMetal_1.ogg, Raid_FolkMetal_2.ogg, Raid_1.ogg through Raid_3.ogg, Flap_1.ogg, Flap_2.ogg

### VFX Frames — each PNG is a sprite sheet (not a frame)
```gdscript
# Correct: call VFXManager, which slices each PNG into per-row animations.
VFXManager.play_single("hit_sparks", hit_position, 2.0, 0.12, 618)
VFXManager.play("ko", global_position, 2.0, 19)

# Incorrect (do NOT do this — renders a 768×576 block on screen):
#   var frames = DirAccess.get_files_at("res://assets/vfx/hit_sparks/")
#   frames.sort()  # each PNG is a SHEET, not a single frame
```
See the VFX System section for sheet dimensions, pinned anim_idx values, and the pinning workflow.

---

## Platform Building Protocol — MANDATORY

This protocol applies every time a stage platform is created or modified. Seamless visuals take priority over matching the reference image layout exactly. The reference images show the desired structural logic (two ground sections, gap, floating platforms above) — they are not pixel-perfect targets to clone.

### Step 1: Measure the asset before using it

Before placing any platform sprite or tile, read the actual pixel dimensions of the source image and log them. Never assume a tile size.

```gdscript
# Example — run this and read the output before building anything:
var tex = load("res://assets/stages/desert_temple/platforms/desert_platforms.png")
print("Sheet size: ", tex.get_width(), "x", tex.get_height())
# Then divide by known grid (256x256 for desert) to confirm piece count
```

For tilesets (ruins_platform_tiles.png), inspect the image to identify the repeating grid unit. Look for the smallest repeated element and measure it. Common sizes are 16×16, 32×32, 48×48. Confirm before creating the TileSet.

### Step 2: Never scale a platform sprite to fit a space

**This is the single most common cause of visual seams. It is absolutely forbidden.**

- Do NOT set `scale` on any platform Sprite2D to make it wider or taller
- Do NOT stretch a TextureRect to fill a space
- Do NOT use `region_rect` to crop a tile and then scale the result

If a ground section needs to be 480px wide and your tile is 64px wide, place 7–8 tiles edge to edge. If a floating island piece is 256×256, place it at 1:1 scale. Platforms get their size from the number of tiles placed, never from scaling a single tile.

### Step 3: Build one section at a time, screenshot after each

Do not build the entire stage layout at once. Build in this order, taking a screenshot and verifying after each:

1. Build the LEFT ground section only → screenshot → check edges are seamless
2. Build the RIGHT ground section (mirror) → screenshot → check it matches the left visually
3. Build one floating platform → screenshot → check it looks self-contained and correct
4. Place all platforms in the full layout → screenshot → check overall composition

If a section has a visible seam, gap, or texture stretch at any step, fix it before continuing. Do not proceed to the next section until the current one looks correct.

### Step 4: Seamless verification checklist

After each screenshot, specifically check:
- **No visible seam lines** between adjacent tiles on the same platform
- **No texture stretching** — pixels should be crisp, not blurred or elongated
- **Platform edges** end cleanly — no half-tiles or cut-off pixels at the ends
- **Left and right ground sections** use identical tile arrangement (mirror each other)
- **Floating platforms** sit at 1:1 scale with no distortion
- **The gap between ground sections** is clean empty space — no stray pixels

### Step 5: Layout after seamlessness is confirmed

Only after all individual platform sections pass the seamless check, position them in the full layout. Use the reference image at `res://references/[stage]_reference.png` as a guide for approximate positions and proportions, but adjust positions freely if it makes the stage look better. The reference is inspiration, not specification.

### Asset-specific slicing instructions

**desert_platforms.png (256×256 grid):**
Each named piece occupies one or more 256×256 cells. Load the full sheet as a Texture2D, then use `AtlasTexture` with `region` set to the correct cell coordinates to extract each named piece. Place each piece as a Sprite2D at 1:1 scale. Do not combine pieces into a single stretched sprite.

**ruins_platform_tiles.png (tileset):**
This is a categorized tileset — Ground & Cliff Tiles, Floating Island Tiles, Ruin Tiles, etc. Measure the tile grid size from the image first. Create a `TileSet` resource, import the sheet, and define the tile size. Use a `TileMap` node to paint tiles. Ground sections = painted rows of ground/cliff tiles. Floating platforms = painted from floating island tile category.

**floating_platforms.png (Windrise):**
Already in the project and working. Use the same TileMap approach — measure the repeating tile unit and paint rather than scale.

---

## Screenshot Pipeline

Use this system any time you need to verify how a level, stage, or UI scene looks during development. The workflow is: build something → trigger a screenshot in-game → read the saved file → assess and iterate.

### Folder

Screenshots save to `res://screenshots/` (i.e., `fantasy-fighter/screenshots/`). This folder is gitignored but always exists locally. Create it if missing:

```
fantasy-fighter/
└── screenshots/        ← auto-saved PNGs land here
```

### The Screenshot Tool Script

Create this file at `scripts/tools/ScreenshotTool.gd` and add it as an **autoload singleton** named `ScreenshotTool` (Project → Autoload). It runs in every scene automatically.

```gdscript
# scripts/tools/ScreenshotTool.gd
# Autoload singleton — active in every scene.
# Hotkeys:
#   F12        → screenshot named by current scene + timestamp
#   F11        → screenshot with a custom label (prompts via print, pass label in code)
# Saved to: res://screenshots/

extends Node

const SCREENSHOT_DIR := "res://screenshots/"
const HOTKEY_CAPTURE := KEY_F12
const HOTKEY_LABELED := KEY_F11

var _pending_label: String = ""

func _ready() -> void:
    # Ensure the screenshots directory exists
    if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR)):
        DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F12:
                take_screenshot()
            KEY_F11:
                take_screenshot(_pending_label if _pending_label != "" else "labeled")

func take_screenshot(label: String = "") -> String:
    # Build filename: [scene]_[label_]YYYYMMDD_HHMMSS.png
    var scene_name := get_tree().current_scene.name.to_lower() if get_tree().current_scene else "unknown"
    var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
    var label_part := (label + "_") if label != "" else ""
    var filename := "%s_%s%s.png" % [scene_name, label_part, timestamp]
    var full_path := ProjectSettings.globalize_path(SCREENSHOT_DIR + filename)

    # Capture and save
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    image.save_png(full_path)

    print("[ScreenshotTool] Saved: ", full_path)
    _pending_label = ""
    return full_path

# Call this from code before F11 to name the next screenshot:
#   ScreenshotTool.set_label("windrise_platform_layout")
#   (then press F11 in-game)
func set_label(label: String) -> void:
    _pending_label = label
```

### Taking Screenshots From Code (No Hotkey Needed)

For automated capture during development — e.g., after a scene loads, after placing all platforms — call `take_screenshot()` directly from any script:

```gdscript
# In a stage script, after _ready() finishes building the layout:
func _ready() -> void:
    _build_platforms()
    _setup_parallax()
    # Auto-capture layout for Claude Code review:
    await ScreenshotTool.take_screenshot("layout_check")
```

This is the preferred method when building levels and UI — capture automatically at the end of `_ready()` so you don't have to remember to press a key.

### How Claude Code Should Use Screenshots

**When building a stage or UI scene**, always end `_ready()` with an auto-capture as shown above. After running the scene with `mcp__godot__run_project`, read the most recent PNG from the screenshots folder:

```gdscript
# After run_project completes, read the latest screenshot:
var files = DirAccess.get_files_at("res://screenshots/")
files.sort()
var latest = files[-1]  # most recent by name (timestamp-sorted)
# Path to hand to Claude Code's Read tool:
# res://screenshots/{latest}
```

Then use the Read tool on that path to view the image and assess:
- Are platforms positioned correctly and visually balanced?
- Does the parallax layering look right (depth/separation)?
- Is the HUD readable and correctly anchored?
- Are UI panels/buttons sized and spaced correctly?
- Does the overall composition look good at 1280×720?

If something looks wrong, adjust node positions/sizes and capture again before moving to the next phase.

### Screenshot Checklist — When to Capture

| Phase | What to capture | Label to use |
|-------|----------------|--------------|
| After placing stage platforms | Full stage layout | `"layout"` |
| After setting up parallax | Parallax layer depth check | `"parallax"` |
| After building HUD | HUD with placeholder health values | `"hud"` |
| After building Character Select | Full character grid | `"charselect"` |
| After building Main Menu | Full menu screen | `"mainmenu"` |
| After any UI panel | Panel with all elements visible | `"ui_[name]"` |
| After wiring a character's animations | Idle pose on stage | `"[char]_idle"` |

---

## Definition of Done

The game is complete when:
- [ ] All 9 characters are selectable and playable with working animations
- [ ] All 3 stages load with correct backgrounds, platforms, and music
- [ ] 2-player local matches work on keyboard and controller
- [ ] Stock system, damage, knockback, and win condition all function
- [ ] HUD displays health and stocks correctly
- [ ] VFX and SFX play on hits, deaths, and interactions
- [ ] Full menu flow works (main menu → character select → stage select → battle → win screen → back)
- [ ] Game runs without crashes on macOS
