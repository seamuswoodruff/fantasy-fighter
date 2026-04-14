# Fantasy Fighter — Claude Code Project Brief

## Working with Claude Code — Critical Workflow Rules

These rules come from hard-won community experience building Godot games with Claude Code. Follow them to avoid the most common failure modes.

### Context Window is the #1 Constraint
Your entire conversation — every message, every file read, every error log — fills the context window. When it fills up, Claude starts "forgetting" earlier instructions and making more mistakes. Manage it aggressively:

- **Run `/clear` between each development phase.** Finish Phase 2, commit it, `/clear`, then start Phase 3 fresh.
- **After correcting the same mistake twice in a row**, don't keep correcting — run `/clear` and restart with a better, more specific prompt. A clean session with a smarter prompt beats a long polluted one every time.
- **Resume sessions** using the session history in the Claude app UI rather than re-explaining context from scratch. Treat each phase as its own named session.
- **Use subagents for research.** If you need Claude to explore the codebase before implementing something, say "use a subagent to investigate X." Subagents run in their own context and report back summaries, keeping the main session clean.

### GDScript API Hallucination — The Biggest Godot-Specific Problem
Godot has ~850 classes. Claude was trained on GDScript but will sometimes hallucinate method names that "look right" (e.g., `get_node_by_name()` instead of `find_child()`). This is the #1 source of bugs in AI-generated GDScript.

**The best fix: install the GDScript LSP plugin before starting development.**

This plugin bridges Claude Code to Godot's built-in language server over TCP, giving Claude the same real-time type info, diagnostics, and go-to-definition intelligence that the Godot editor itself uses. No guessing, no hallucinated API names.

```
# Install (run once, before starting development):
git clone https://github.com/Sods2/claude-code-gdscript-lsp.git
cd claude-code-gdscript-lsp
./scripts/install.sh
```

The script builds a lightweight Node.js bridge (~200 lines, zero runtime deps), links it globally, and registers the plugin with Claude Code. Restart Claude Code after install.

**How it works:**
```
Claude Code  ↔  Bridge (stdio)  ↔  Godot LSP (TCP:6005)
```
Godot 4 ships with a built-in LSP server. The bridge translates between the two protocols and buffers messages while Godot isn't running yet.

**Usage:** Open your project in the Godot Editor first (this starts the LSP server on port 6005), then start your Claude Code session pointed at this project directory. Code intelligence will be live. If you prefer not to have the editor open, run Godot headless in a terminal:
```
godot --editor --headless --lsp-port 6005
```

Verify it's working: `claude plugin list` should show `gdscript-lsp` as enabled.

**Requirements:** Claude Code v2.0.74+, Godot 4.x, Node.js 18+

**If the LSP plugin isn't installed**, fall back to these manual safeguards:
- Always run `run_project` + `get_debug_output` after every new script — don't batch multiple scripts without testing.
- When a method isn't working, check the exact error in debug output and verify against Godot 4 docs rather than guessing.
- Prefix uncertain API calls with `# verify this method exists in Godot 4.6` as an audit marker.
- Trust the error output over assumptions — GDScript errors are specific.

### Explore → Plan → Implement (Don't Skip Steps)
For any phase that touches multiple files or systems:
1. **Explore first** (Plan Mode, `Shift+Tab` to toggle): read existing files, understand patterns
2. **Plan**: ask Claude to write out what it intends to change before touching anything
3. **Implement**: execute the plan, verifying at each step
4. **Commit**: commit working code before starting the next chunk

Never ask Claude to implement a whole phase in one shot. Break it into pieces (e.g., "implement movement only, not combat") and verify each piece runs before continuing.

### Verify Everything — Don't Trust "Looks Right"
- **Always run the project** after each implementation step. Don't assume it works.
- **Use the screenshot pipeline** (F12 or `ScreenshotTool.take_screenshot()`) to visually check every stage layout and UI screen before moving on.
- **Always check `get_debug_output`** after `run_project` — errors in the output mean bugs that need fixing before proceeding.
- After any character animation work, run the scene and take a screenshot to confirm sprites are loading correctly and frames are sliced right.

### Godot MCP Tools Available in This Session
The following MCP tools are available via `@coding-solo/godot-mcp` (already configured in Claude Desktop):

| Tool | Use for |
|------|---------|
| `run_project` | Run the game and start playing/testing |
| `get_debug_output` | Read console errors and print statements |
| `stop_project` | Stop a running game |
| `create_scene` | Create new .tscn files |
| `add_node` | Add nodes to scenes |
| `load_sprite` | Assign a texture to a Sprite2D |
| `save_scene` | Save scene changes |
| `launch_editor` | Open the Godot editor GUI |
| `get_project_info` | Inspect project structure |
| `get_uid` / `update_project_uids` | Fix UID reference errors (Godot 4.4+) |

**Preferred workflow:** write scripts with the `Edit`/`Write` file tools, then use `run_project` + `get_debug_output` to test. Use `add_node` / `create_scene` MCP tools when building scene structure, but write all GDScript logic by editing `.gd` files directly.

### Phase Commit Discipline
At the end of every phase, before `/clear`-ing and moving on:
1. Verify the game runs without errors (`run_project` + `get_debug_output`)
2. Take a screenshot to document the current state
3. Make a git commit with a descriptive message
4. Then `/clear` and start the next phase fresh

---

## Skill Requirement — Read Before Writing Any Code

**Before writing any GDScript, creating any scene, or implementing any game mechanic, you MUST invoke the `game-development` skill.** This applies every time you begin a new coding task, not just at session start.

The game-development skill contains Godot-specific patterns for state machines, player controllers, object pooling, event systems, and performance optimization. All code written for this project must follow those patterns. Do not write game code from scratch without consulting the skill first.

To invoke: use the Skill tool with `skill: "game-development"` before each implementation phase.

---

## Project Overview

A 2D local-multiplayer platform fighter (Smash Bros-style) built in Godot 4.6.2 using GDScript. Two players fight on a stage, dealing damage to knock each other off. The game must run on macOS, support local multiplayer, and support game controllers.

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
│   │   ├── dungeon/
│   │   │   ├── background/ (dungeon_.png)
│   │   │   ├── platforms/  (dungeon_.png, terrain_tiles.png)
│   │   │   └── foreground/ (ceiling_sky.png)
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

### Archetypes

**Warriors** (knight_1, knight_2, knight_3)
- Archetype: Heavy, high damage, medium speed, shorter range
- Playstyle: Close-range brawlers with strong melee combos
- Special mechanic: Shield/block absorbs one hit

**Wizards** (fire_wizard, lightning_mage, wanderer_magician)
- Archetype: Light, lower HP, fast projectiles, medium speed
- Playstyle: Zoners who keep distance and cast spells
- Special mechanic: Projectile attack (spawns magic VFX that travels across screen)

**Samurai** (samurai, samurai_archer, samurai_commander)
- Archetype: Medium weight, high speed, precise attacks
- Playstyle: Fast rushdown with quick multi-hit combos
- Special mechanic: Dash attack (brief invincibility frames during dash)

### Character Stats

| Stat | Warriors | Wizards | Samurai |
|------|----------|---------|---------|
| Max HP | 150 | 100 | 120 |
| Move Speed | 200 | 220 | 260 |
| Jump Force | -550 | -600 | -580 |
| Attack Damage (light) | 12 | 8 | 10 |
| Attack Damage (heavy) | 22 | 15 | 18 |
| Knockback Multiplier | 1.0 | 0.8 | 0.9 |

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
- **Special attack** (B button / C key): Character-specific (projectile for wizards, charge for warriors, dash attack for samurai)
- **Block/Shield** (L trigger / left shift): Reduces incoming damage by 60%, cannot move while blocking
- Attacks have 3 phases: startup frames (no hitbox), active frames (hitbox live), recovery frames (vulnerable)
- **Hitstun:** Receiving a hit freezes the character briefly (5–12 frames depending on attack weight)
- **Knockback:** Applies an impulse velocity to the struck character. Heavy attacks at low HP = horizontal knockback. Heavy attacks at high HP = diagonal.

### Hitboxes / Hurtboxes
- Use `Area2D` nodes for hitboxes (attack zones) and hurtboxes (damageable zones)
- Separate collision layers: Layer 1 = world, Layer 2 = player hurtboxes, Layer 3 = attack hitboxes
- Hitboxes only active during active frames of animations
- Characters are immune during respawn (2-second invincibility)

### Stock / Lives System
- Each player starts with 3 stocks (lives)
- Death trigger: fall below the stage kill zone (a large Area2D below the platforms) OR HP reaches 0
- On death: play KO animation/VFX, decrement stock counter, respawn after 1.5 seconds at spawn point
- When stocks reach 0: player is eliminated, match ends

---

## Input System

### InputMap Actions (define in Project Settings → Input Map)
All actions must support both keyboard AND controller:

| Action | Player 1 Keyboard | Player 2 Keyboard | Controller (both players) |
|--------|------------------|------------------|--------------------------|
| `p{n}_left` | A | Left Arrow | Left Stick Left / DPad Left |
| `p{n}_right` | D | Right Arrow | Left Stick Right / DPad Right |
| `p{n}_up` | W | Up Arrow | Left Stick Up / DPad Up |
| `p{n}_down` | S | Down Arrow | Left Stick Down / DPad Down |
| `p{n}_jump` | Space | Numpad 0 | A (Xbox) / Cross (PS) |
| `p{n}_light_attack` | Z | Numpad 1 | X (Xbox) / Square (PS) |
| `p{n}_heavy_attack` | X | Numpad 2 | Y (Xbox) / Triangle (PS) |
| `p{n}_special` | C | Numpad 3 | B (Xbox) / Circle (PS) |
| `p{n}_block` | Left Shift | Right Shift | LB/L1 or LT/L2 |
| `p{n}_dash` | Double-tap A/D | Double-tap Left/Right | Right Stick or RB/R1 |

Where `{n}` = 1 or 2. Use `device` parameter on InputEvents to differentiate controllers.

### Controller Detection
- Detect connected controllers with `Input.get_connected_joypads()`
- Player 1 = joypad device 0 (or keyboard fallback)
- Player 2 = joypad device 1 (or keyboard fallback)
- Show controller icon prompts using the controller icons in `assets/ui/menus/fantasy_ui.png`

---

## Stages

### Stage 1: Windrise
**Theme:** Bright outdoor field, daytime, pastoral/majestic  
**Visual layers (back to front):**
1. Sky background: `windrise-background.png` (or `windrise-background-4k.png` for high res)
2. Distant mountains: `mountains.png` (parallax layer, moves at 0.3× camera speed)
3. Hills: `hills.png` (parallax layer, moves at 0.6× camera speed)
4. Platforms: `floating_platforms.png`
5. Foreground decoration: `decors.png` (moves at 1.2× camera speed)

**Platform layout:**
- One large main platform (ground level, spans ~70% of screen width)
- Two floating platforms (mid height, left and right of center)
- One small platform (high center)

**Music:** Randomly pick from Prairie_3, Prairie_4, Prairie_5, BattleField_1–5, EpicBattle (files in `assets/music/`)  
**Ambience:** `forest_day` OGG, played at low volume under music

---

### Stage 2: Dungeon
**Theme:** Dark underground, torchlit, oppressive  
**Visual layers:**
1. Dark background: `dungeon_.png` (from background folder)
2. Ceiling element: `ceiling_sky.png` (top of screen, foreground)
3. Platforms: `dungeon_.png` + `terrain_tiles.png` (from platforms folder — use terrain_tiles as tilesets)

**Platform layout:**
- No true "ground" — players fight on floating stone ledges
- Three platforms at staggered heights
- Narrower platforms than Windrise — more aggressive, closer quarters

**Music:** Randomly pick from Gothic_Dark, Demise, Havoc, Fight_1–3, Crisis  
**Ambience:** `cave` or `interior` OGG

---

### Stage 3: Desert Temple
**Theme:** Warm ancient ruins, sandy, mystical  
**Visual layers:**
1. Temple walls background: `temple_walls.png`
2. Platforms: `temple_platforms.png`

**Platform layout:**
- Two large stone platform slabs at ground level (with a gap in the middle)
- Two smaller elevated platforms above each slab
- Central top platform

**Music:** Randomly pick from Raid_Ethnic, Raid_FolkMetal_1–2, Raid_1–3, Flap_1–2  
**Ambience:** `water` or `forest_night` OGG (desert wind atmosphere)

---

## VFX System

VFX are sprite-sheet sequences stored as individual PNG frames in subdirectories.

| Folder | Usage | Trigger |
|--------|-------|---------|
| `vfx/hit_sparks/` | Melee impact flash | On successful light/heavy hit |
| `vfx/magic/` | Spell effects, projectile bodies, explosions | Wizard specials, magic impacts |
| `vfx/ko/` | Knockout explosion, star burst | When a player loses a stock |
| `vfx/dust/` | Landing puff, dash trail, footstep cloud | Jump land, dash start, fast movement |

**VFX Implementation:**
- Create a `VFXManager` autoload singleton
- `VFXManager.play(effect_name, position, scale)` spawns a one-shot `AnimatedSprite2D`
- Preload all VFX frame sequences on game start
- Auto-free nodes after animation completes (`animation_finished` signal)
- Parse frame sequences by loading all PNGs from the relevant subfolder, sorted by filename

---

## Audio System

### AudioManager (Autoload Singleton)
```gdscript
# Manages all game audio with categories
# Methods:
# AudioManager.play_sfx(sfx_name)       — plays one-shot sound
# AudioManager.play_music(track_name)   — crossfades to new music track
# AudioManager.play_ambience(amb_name)  — loops ambience track
# AudioManager.stop_music()
# AudioManager.set_volume(category, db) — "music", "sfx", "ambience"
```

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
│       ├── Player1HUD (health bar, stock icons, damage %)
│       └── Player2HUD
│
└── WinScreen (scenes/ui/WinScreen.tscn)
```

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

#### `scripts/characters/Warrior.gd` (extends Character)
- Overrides `special_attack()`: enters block state for 0.5s, absorbs next hit

#### `scripts/characters/Wizard.gd` (extends Character)
- Overrides `special_attack()`: spawns `Projectile` scene at character position, traveling in facing direction
- `scripts/characters/Projectile.gd`: moves horizontally, damages on contact, despawns at screen edge

#### `scripts/characters/Samurai.gd` (extends Character)
- Overrides `special_attack()`: dashes forward with hitbox active, brief i-frames

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
   - Layer 1: World/Platforms
   - Layer 2: Player Hurtboxes
   - Layer 3: Attack Hitboxes
   - Layer 4: Kill Zones
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
6. Make knight_1 a `Warrior` subclass with shield special

---

### Phase 4: First Stage (Windrise)
1. Create `scenes/stages/Windrise.tscn`
2. Set up `ParallaxBackground` with layers:
   - Layer 1 (motion scale 0.2): `windrise-background.png` or `windrise-background-4k.png`
   - Layer 2 (motion scale 0.4): `mountains.png`
   - Layer 3 (motion scale 0.7): `hills.png`
3. Add platforms as `StaticBody2D` + `CollisionShape2D` + `Sprite2D` using `floating_platforms.png`
4. Add `decors.png` as a foreground `Sprite2D` (no collision)
5. Add kill zones: `Area2D` nodes at bottom (Y > 800), left (X < -200), right (X > 1480), top (Y < -300)
6. Add two `Marker2D` spawn points (left-center and right-center above main platform)
7. Create `BattleScene.tscn` — instantiate Windrise, spawn two knight_1 instances

---

### Phase 5: Combat System
1. Implement hitbox → hurtbox collision detection:
   - Hitbox `area_entered` signal → call `target.take_damage(damage, direction, is_heavy)`
2. Implement knockback physics:
   - `take_damage` applies velocity impulse to the struck character
   - Light hit: moderate horizontal push + small upward
   - Heavy hit: strong horizontal + upward arc
3. Implement hitstun: brief `HURT` state where input is ignored
4. Implement `die()` → stock decrement → respawn with i-frames
5. Add `GameManager` stock tracking and match-end detection
6. Add screen freeze (0.1s) on heavy hit landing (juice)

---

### Phase 6: HUD
1. Create `scenes/ui/HUD.tscn`
2. Add health bars using `HealthBar DARK.png` as frame and a `TextureProgressBar` with `greenbar_1.png` as fill
3. Add stock icons (3 × `rpg_1.png` per player, modulate grey when lost)
4. Connect to `GameManager` signals for stock changes
5. Animate health bar on damage (brief flash/shake)

---

### Phase 7: VFX & Audio Integration
1. Implement `VFXManager`:
   - Preload frame sequences from each `vfx/` subfolder
   - `play(type, position)` — spawns AnimatedSprite2D, auto-frees on finish
2. Wire VFX triggers:
   - `hit_sparks` → on any hit
   - `magic` → on wizard special
   - `ko` → on stock loss (death)
   - `dust` → on landing, dash
3. Implement `AudioManager`:
   - Load all SFX into dictionary on start
   - `play_sfx(name)` plays on SFX bus
   - `play_music(name)` crossfades on Music bus
4. Wire audio triggers per the SFX Trigger Map above
5. Start stage music and ambience when BattleScene loads

---

### Phase 8: All 9 Characters
Repeat Phase 3 for remaining characters. Create:
- `scripts/characters/Warrior.gd` (knight_2, knight_3 inherit)
- `scripts/characters/Wizard.gd` (fire_wizard, lightning_mage, wanderer_magician inherit)
- `scripts/characters/Samurai.gd` (samurai, samurai_archer, samurai_commander inherit)
- `scripts/characters/Projectile.gd` for wizard specials

Each character gets its own `.tscn` scene that inherits Character.tscn and sets its specific:
- Sprite frames (from their sprites/ folder)
- Stats (HP, speed, damage — see Character Stats table)
- Script (Warrior / Wizard / Samurai)

---

### Phase 9: All 3 Stages
Repeat Phase 4 for Dungeon and Desert Temple:
- `scenes/stages/Dungeon.tscn`
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
Dungeon stage: Gothic_Dark.ogg, Demise.ogg, Havoc.ogg, Fight_1.ogg through Fight_3.ogg, Crisis.ogg  
Desert Temple: Raid_Ethnic.ogg, Raid_FolkMetal_1.ogg, Raid_FolkMetal_2.ogg, Raid_1.ogg through Raid_3.ogg, Flap_1.ogg, Flap_2.ogg

### VFX Frames — load all PNGs from folder, sorted, as animation frames
```gdscript
var frames = DirAccess.get_files_at("res://assets/vfx/hit_sparks/")
frames.sort()  # ensures correct playback order
```

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
