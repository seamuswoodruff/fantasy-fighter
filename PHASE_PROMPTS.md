# Fantasy Fighter — Phase Prompts

Paste each prompt at the start of a fresh Claude Code session (after /clear).
Always open the Godot editor first so the GDScript LSP is live on port 6005.

---

## PHASE 4 FIX — Windrise Stage Rebuild
*(Run this in your current session before clearing — no need to restart)*

```
Read CLAUDE.md in full before doing anything else, paying close attention to the
Stage Layout Philosophy section and the Platform Building Protocol section.

The existing Windrise stage platform layout needs to be rebuilt from scratch.
The current implementation is not using the platform assets correctly.

Follow the Platform Building Protocol exactly:
1. First, measure floating_platforms.png — log its actual pixel dimensions before
   writing any code. Identify the tile unit size from the repeating grid.
2. Build the LEFT ground section only using a TileMap. Screenshot it. Verify it
   looks seamless with no stretching before continuing.
3. Build the RIGHT ground section as a mirror. Screenshot. Verify it matches the
   left visually.
4. Build each floating platform (left float, right float, top center) one at a
   time, screenshot after each.
5. Only after all sections pass the seamless check, assemble the full layout.

Use res://references/windrise_reference.png as a layout guide for approximate
positions only — adjust freely if it makes the stage look better. Seamless
visuals are the acceptance criteria, not matching the reference exactly.

Do not scale any sprite to fit a space. Platform width comes from tile count,
never from scale values.

After the full stage is assembled, run the project, take a screenshot, and verify:
no seams, no stretched textures, ground sections have real visual weight, gap is
clean, floating platforms look self-contained. Fix anything that fails this check.
Commit when the stage looks correct.
```

---

## PHASE 5 — Combat System
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else. Pay close attention to the
Combat section and the Death & Stock System section.

Phases 1–4 are complete. Windrise.tscn has a TileMap-based platform layout with
two chunky ground sections flanking a central gap, two mid floating platforms,
and one top center platform. knight_1 is fully playable with working animations,
movement, and state machine. BattleScene.tscn spawns two knight_1 instances.

Invoke the game-development skill, then begin Phase 5 (Combat System).

CRITICAL: This is HP-based combat. Do NOT implement damage percentage
accumulation or percentage-based knockback scaling. There is no damage meter.
Attacks subtract flat values directly from current_hp.

Implement in this exact order, running the project and checking debug output
after each step:

1. Wire hitbox Area2D area_entered signal to target.take_damage()
2. Implement take_damage(amount, attacker_pos, is_heavy):
   - Subtract amount from current_hp
   - Direction = sign(target.position.x - attacker_pos.x)
   - Light knockback: Vector2(direction * 200, -120)
   - Heavy knockback: Vector2(direction * 350, -200)
   - Enter HURT state for hitstun tracked with a `_hitstun_timer` float (light: 0.5s, heavy: 1.2s). Do NOT rely on animation_finished to exit HURT — this causes a freeze bug when the animation ends slightly before the timer. Instead, add a dedicated exit check in _tick_timers():
     ```gdscript
     func _tick_timers(delta: float) -> void:
         if _hitstun_timer > 0.0:
             _hitstun_timer -= delta
             if _hitstun_timer <= 0.0 and state == State.HURT:
                 change_state(State.IDLE)
     ```
     This ensures HURT always exits when the timer runs out, regardless of animation timing.
   - If current_hp <= 0: call die()
3. Wire kill zone body_entered to also call die()
4. Implement die(): decrement stock, disable character (set process_mode =
   PROCESS_MODE_DISABLED and hide), respawn after 1.5 seconds with 2 seconds
   of invincibility frames (is_invincible = true, re-enable character).
   Do NOT call VFXManager or AudioManager here — those are wired in Phase 7.
5. GameManager stock tracking — emit match_ended(winner_id) when stocks hit 0
6. Add 0.1s Engine.time_scale = 0 freeze on heavy hit landing, restore after

After all steps: have both knight_1 instances fight. Confirm HP depletes on hits,
stocks decrement on death, match ends correctly, respawn works with i-frames.
Take a screenshot. Commit before stopping.
```

---

## PHASE 6 — HUD
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else.

Phases 1–5 are complete. Combat works: HP depletes from flat damage, fixed
knockback applies on hits, die() decrements stocks and respawns with i-frames,
GameManager tracks stocks and detects match end.

Invoke the game-development skill, then begin Phase 6 (HUD).

Create scenes/ui/HUD.tscn as a CanvasLayer so it stays fixed on screen.

Assets are in assets/ui/hud/ — list the files there first to see what's
available before building anything.

Build the HUD with:
1. Player 1 panel (bottom-left): health bar using HealthBar DARK.png as the
   frame and a TextureProgressBar with greenbar_1.png as fill texture. The
   bar value = current_hp / max_hp updated every frame.
2. Player 2 panel (bottom-right): mirror layout of Player 1.
3. Stock icons: 3 x rpg_1.png icons per player. When a stock is lost, modulate
   the corresponding icon to Color(0.3, 0.3, 0.3) (greyed out). Rightmost icon
   lost first for P1, leftmost for P2.
4. When HP drops below 25% of max, swap the fill texture from greenbar_1.png
   to redblue_1.png as a low-health warning.
5. Connect to GameManager's stock_lost signal and Character's current_hp
   property. Do not poll GameManager every frame — use signals for stocks,
   poll current_hp in _process for the health bar.

Add BattleScene.tscn instantiation of HUD.tscn as a child.

Run the project. Take a screenshot of the HUD visible on screen with both
characters. Verify: health bars are readable, stock icons are correct size and
position, low-health color swap works (temporarily reduce a character's HP in
code to test). Fix anything that looks wrong. Commit before stopping.
```

---

## PHASE 7 — VFX & Audio Infrastructure
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else. Focus on the VFX System
section, the Audio System section, and the HUD Architecture Notes (Phase 6
added important invariants you must not regress).

Phases 1–6 are complete. Current state:
- BattleScene loads, both knight_1 players fight, stocks decrement, match ends
- HUD is fully wired: health bars (green/redblue swap at 25%), 3 procedural
  pixel-art hearts per player, depletion sorted by position.x, P2 respawn
  faces left via spawn_facing_right convention
- knight_1 AnimatedSprite2D position is Vector2(16, -26) — do not change
- VFXManager and AudioManager exist as autoload STUBS with no implementation
- assets/sfx/, assets/music/, assets/vfx/ are fully populated and ready

Invoke the game-development skill, then begin Phase 7.

This phase builds the manager systems only and wires them into knight_1 as a
proof of concept. The remaining 8 characters will have triggers wired in
during Phase 8 as each character is built. Do NOT try to wire all characters
here — just prove the systems work on knight_1.

INVARIANTS TO PRESERVE (from Phase 6 — do not regress):
- die() must set change_state(State.DEAD) on its first line after the guard
- respawn() teleports BEFORE setting process_mode = DISABLED
- BattleScene._on_kill_zone_entered checks character.is_invincible
- current_hp snaps to 0.0 when it drops below 1.0
- HURT state exits from _tick_timers(), not animation_finished
- Heart array sorts by position.x, never by node name
- No StyleBoxEmpty sub-resources in HUD.tscn (Godot strips them on save)
Adding VFX/audio calls must not reorder or remove any of the above.

PART A — VFXManager (scripts/managers/VFXManager.gd):
1. On _ready, scan each subfolder in res://assets/vfx/ and load all PNGs
   into arrays sorted by filename (so frames play in correct order).
   Use DirAccess.get_files_at() then .sort() — sorted filename order is
   the frame order for every VFX sequence in this project.
2. play(type: String, position: Vector2, scale: float = 1.0): spawns a
   one-shot AnimatedSprite2D at the given position, plays the full frame
   sequence, connects animation_finished to queue_free. Add the node as a
   child of get_tree().current_scene so it renders in world space.
3. Supported types: "hit_sparks", "magic", "ko", "dust"
4. Register as autoload named VFXManager (replace the stub — do not create
   a second autoload)

PART B — AudioManager (scripts/managers/AudioManager.gd):
1. On _ready, preload all WAV files from assets/sfx/ subdirs into a nested
   dictionary keyed by category then name (e.g. sfx["impacts"]["hit_1"])
2. play_sfx(name: String): looks up across all categories; if multiple
   files share a name prefix (e.g. hit_1.wav, hit_2.wav, hit_3.wav), pick
   one at random. Play via a pooled AudioStreamPlayer on the SFX bus.
3. play_music(track_name: String): crossfades to new OGG on the Music bus
   using a Tween on volume_db (-80 → 0 over 1 second on the new player,
   current player fades 0 → -80 over 1 second then stops)
4. play_ambience(name: String): loops OGG on the Ambience bus at -12db
5. stop_music(): fades out current music over 1 second
6. set_volume(bus_name: String, db: float): sets volume on the named bus
   (Master, Music, SFX, or Ambience — buses are already configured)
7. Register as autoload named AudioManager (replace the stub)

PART C — Wire into knight_1 as proof of concept:
- On hit landed (inside _apply_hit, after damage resolves):
    VFXManager.play("hit_sparks", hit_position)
    AudioManager.play_sfx("hit")  # or heavy hit variant if is_heavy
- In die(), AFTER change_state(State.DEAD) and GameManager.on_player_death:
    VFXManager.play("ko", global_position)
    AudioManager.play_sfx("ko")  # if any KO sfx exists; otherwise skip
- On landing from jump (inside the existing coyote-time / landing transition
  in _update_coyote or wherever the floor-enter detection lives):
    VFXManager.play("dust", global_position + Vector2(0, 32))
- On light attack start (when entering ATTACK_LIGHT state):
    AudioManager.play_sfx("sword_swing")  # pick nearest match in attacks/
- On heavy attack start: same pattern with a heavier swing variant

PART D — Wire stage audio in BattleScene._ready():
- AudioManager.play_music(<random from Windrise list>)
  Windrise music pool: Prairie_3, Prairie_4, Prairie_5, BattleField_1–5,
  EpicBattle (pick one via randi() % pool.size())
- AudioManager.play_ambience("forest_day")

VERIFICATION:
Run the project with two knight_1 players. Verify, via both gameplay and
get_debug_output:
- Hit sparks appear on contact (visible sprite, not just a log)
- KO VFX plays on stock loss
- Dust plays when a character lands from a jump
- Attack swing SFX plays on button press, impact SFX plays on hit
- Stage music starts playing and ambience loops underneath
- HUD still updates correctly, health bars swap color at 25%, stocks still
  deplete in the correct order — Phase 6 behavior is unchanged
- No errors in get_debug_output

Take a screenshot at the moment of a hit connect so the spark VFX is visible.
Commit with a message like "Phase 7: VFX + Audio managers + knight_1 wiring".
```

---

## PHASE 8 — All 9 Characters (with VFX & Audio triggers)
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else. Read the entire Characters
section carefully — each character has their own script with specific animation
names and unique mechanics. Also read the Sprite Sheet Convention section, the
VFX System section (note the pinned anim_idx values), and the Audio System
section (note the SFX group semantics).

Phases 1–7 are complete. Current state:
- knight_1 is fully playable with VFX and audio wired
- VFXManager and AudioManager are fully implemented autoloads — do NOT rebuild
  them. Reuse the pinned calls from CLAUDE.md's VFX System section.
- knight_1 AnimatedSprite2D position = Vector2(16, -26) — reference value only
- HUD, combat, stocks, respawn i-frames all working. Do not regress Phase 6/7
  invariants (see their subsections in CLAUDE.md).
- IMPORTANT: the knight script file is currently named scripts/characters/
  Warrior.gd. CLAUDE.md calls it Knight.gd everywhere. Before starting the
  character work, rename Warrior.gd → Knight.gd (update the class_name, any
  preload paths, and the Warrior.gd.uid file). Run the project and verify
  knight_1 still loads, moves, attacks, dies correctly. Only then proceed.

Invoke the game-development skill, then begin Phase 8 (All 9 Characters).

There are 6 scripts to create/confirm. Build each script and all characters
that use it before moving to the next. Wire VFX and audio triggers into each
character as you build it — do not leave triggers for a separate pass.

For every character: list their sprites/ folder to confirm animation filenames
before referencing them in code. Frame count = image width / 128.

REUSE THESE PINNED CALLS (do not re-pick anim_idx for melee characters):
- Attack swing (light OR heavy, on state entry):
    AudioManager.play_sfx("Sword Attack")
- Hit connect (in _apply_hit, after take_damage returns):
    VFXManager.play_single("hit_sparks", hit_position, 2.0, 0.12, 618)
    AudioManager.play_sfx("Sword Impact Hit")
- KO / death (in die(), AFTER change_state(State.DEAD) and
  GameManager.on_player_death):
    VFXManager.play("ko", global_position, 2.0, 19)

Wizards and the archer need additional pinned calls for their specials —
pick new anim_idx values for spell cast / projectile impact VFX using the
pinning workflow in CLAUDE.md's VFX System section. Discover spell-cast
and bow-shot SFX group names via `print(AudioManager._sfx_groups.keys())`
at runtime; pick the closest match for each character's theme.

SPRITE OFFSET — required for every character:
Character art is rarely centered in the 128×128 frame. Without a position
offset on AnimatedSprite2D, flip_h causes the character to visually jump when
changing direction. After loading sprites for each character, run the project
briefly and observe: if the body snaps horizontally on direction change,
adjust AnimatedSprite2D.position.x until it stays visually stable. Set
position.y so feet sit on top of the grass (knight_1 uses y = -26; others
will differ). Do this for every character — the offset is per sprite sheet.

SPAWN FACING CONVENTION (from Phase 6):
Every character scene must honor spawn_facing_right on the Character base
class. The right-side player is set to false in BattleScene._ready(). No
per-character code changes needed — just ensure _set_facing() is called
from respawn() (already in place).

---

SCRIPT 1 — Knight.gd (covers knight_1, knight_2, knight_3):
After renaming Warrior.gd → Knight.gd, knight_1 already uses it. Create
knight_2.tscn and knight_3.tscn — they share Knight.gd exactly (pure visual
variants). Key mechanics: Run+Attack (attack input during RUN state triggers
the Run+Attack animation), two defensive states (Protect on block press,
Defend while block held). Wire the three pinned calls above.

---

SCRIPT 2 — Samurai.gd (samurai, samurai_commander):
Both use Attack_1, Attack_2, Attack_3, Run, Jump, Hurt, Dead.
samurai uses Protection for block, samurai_commander uses Protect — detect
which filename exists in each character's sprites/ folder and use the right one.
Attack_3 special: moves character 80px forward during animation, hits up to
3 times for 6 damage each. Block reduces damage 60%.
Wire hit/death/land VFX and audio.

---

SCRIPT 3 — SamuraiArcher.gd (samurai_archer only):
Unique ranged special using Shot + Arrow sprites.
On special: play Shot animation, spawn Arrow projectile (Sprite2D using the
Arrow.png sprite) traveling at 600px/s, 14 damage, despawns after 1000px or
on hit. Can fire in midair. No block. Most mobile character.
Wire magic VFX on arrow spawn, hit_sparks on arrow impact.
Wire audio: bow shot SFX on special.

---

SCRIPT 4 — FireWizard.gd (fire_wizard only):
Two distinct specials based on hold duration:
- Tap special (< 0.5s hold): Charge (0.3s) → Fireball projectile, 450px/s,
  18 damage, despawns after 900px or on hit
- Hold special (≥ 0.5s): Charge → Flame_jet: sustained hitbox in front for
  1 second, 8 damage per 0.2s tick (max 40 total)
Track hold duration with a timer started on special press, check on release.
Wire magic VFX on fireball spawn and impact. Wire magic VFX continuously
during flame_jet (spawn dust particles at character position per tick).
Wire spell_cast audio on special activation.

---

SCRIPT 5 — LightningMage.gd (lightning_mage only):
Two distinct specials based on hold duration:
- Tap special (< 0.8s): Charge → Light_ball, 500px/s, 12 damage
- Hold special (≥ 0.8s): switch to Light_charge animation → release fires
  larger Light_ball, 300px/s, 28 damage + 1 extra second of hitstun on hit
Track hold duration. Switch animation from Charge to Light_charge at 0.8s mark.
Wire magic VFX on ball spawn. Wire spell_cast audio.

---

SCRIPT 6 — WandererMagician.gd (wanderer_magician only):
Two separate specials on different inputs:
- Light special (tap special button): Charge_1 (0.2s) → Magic_arrow,
  550px/s, 10 damage, low cooldown
- Heavy special (hold special button): Charge_2 (0.6s) → Magic_sphere,
  250px/s, pierces through enemy (does not stop on first hit), 22 damage
Wire magic VFX on both projectile spawns. Wire spell_cast audio.

---

AFTER ALL CHARACTERS:
Run the project. Test these specific matchups and verify:
1. knight_1 vs knight_2 — confirm Run+Attack works, both defend states work
2. samurai vs samurai_archer — confirm archer fires arrows, samurai blocks
3. fire_wizard vs lightning_mage — confirm both hold-duration systems work
4. wanderer_magician vs samurai_commander — confirm both specials fire correctly

Check debug output after each test. Fix any errors before the next matchup.
Take a screenshot of each matchup. Commit.
```

---

## PHASE 9 — All 3 Stages
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else. You MUST read and follow
the Platform Building Protocol section for every platform in every stage.
Also read the full Stages section for Ruins and Desert Temple asset details.

Phases 1–8 are complete. Current state:
- All 9 characters implemented, playable, wired with VFX/audio
- BattleScene runs _validate_all_characters() at boot and prints
  "<character> — HP:<n> Spd:<n>" for all 9. Do NOT break this hook.
  Three "invalid UID" warnings at boot are known and harmless (Godot falls
  back to path lookup) — leave them alone.
- Character.tscn Placeholder is visible=false and must stay in tree
  (child-index invariant — see CLAUDE.md Scene Architecture section)
- Windrise is the only stage built. BattleScene currently hardcodes
  Windrise as the stage for dev previews; that default will be replaced
  by CharacterSelect/StageSelect in Phase 10. Do NOT remove the hardcoded
  default in this phase — just ensure Ruins and DesertTemple can be
  swapped in by changing the constant.
- Phase 6, 7, and 8 invariants all hold. Do not regress any of them
  (die() ordering, HURT timer exit, no StyleBoxEmpty in HUD, heart
  sorting by position.x, VFX sheet slicing, 64px projectile frames,
  *_projectile filename convention, etc.).

Invoke the game-development skill, then begin Phase 9 (Ruins and Desert Temple).

BUILD RUINS STAGE (scenes/stages/Ruins.tscn):

Assets: res://assets/stages/ruins/
- Background: ruins_background.png — full scene background
- Platforms: ruins_platform_tiles.png — categorized tileset

Step 1: Load ruins_platform_tiles.png and measure its actual dimensions. Log
the output. Identify the tile grid size from the repeating elements. Do not
assume — measure first.

Step 2: Create a TileSet resource from ruins_platform_tiles.png using the
measured tile size. Identify which tile region corresponds to each category:
Ground & Cliff Tiles, Floating Island Tiles, Ruin Tiles (for decoration).

Step 3: Follow the Platform Building Protocol — build one section at a time,
build based off the ruins reference image in the reference folder.

Step 4: Add ruins_background.png as a Sprite2D background (no parallax needed,
centered). Place spike tile decoration at the bottom of the gap (visual only —
the actual kill zone is an Area2D). Add ruin tile decoration on ground sections.

Step 5: Add kill zones and spawn points using the standard coordinates from
CLAUDE.md (bottom y=850, left x=-250, right x=1530, top y=-300, spawns at
(240,400) and (1040,400)). Add wall barriers: StaticBody2D at x=0 and x=1280
full height — same as Windrise. Wire stage music: random from Gothic_Dark,
Demise, Havoc, Fight_1–3, Crisis. Reference image at
res://references/ruins_reference.png for layout logic.

BUILD DESERT TEMPLE STAGE (scenes/stages/DesertTemple.tscn):

Assets: res://assets/stages/desert_temple/
- Background: desert_background.png — full desert scene
- Platforms: desert_platforms.png — labeled asset sheet, 256×256 grid

Step 1: Load desert_platforms.png. Log its actual dimensions. Verify it divides
evenly on a 256×256 grid. Calculate how many columns and rows of pieces exist.

Step 2: Each named piece (PLAT_MAIN_L, PLAT_MAIN_H, FLOAT_ISL_C, FLOAT_ISL_0,
FLOAT_ISL_1) is one or more 256×256 cells. Extract each using AtlasTexture with
the correct region rect. Place each as a Sprite2D + StaticBody2D at 1:1 scale —
never scaled.

Step 3: Follow the Platform Building Protocol:
build based off the desert reference image in the reference folder.

Step 4: Add desert_background.png as background. Add pillar props from the
sheet as decorative Sprite2D nodes (no collision) on ground sections.

Step 5: Kill zones, spawn points, and wall barriers — use the same standard
coordinates as Windrise (bottom y=850, left x=-250, right x=1530, top y=-300,
spawns at (240,400) and (1040,400), wall barriers at x=0 and x=1280).
Wire music: random from Raid_Ethnic, Raid_FolkMetal_1–2, Raid_1–3, Flap_1–2.
Reference at res://references/desert_reference.png for layout logic only.

After both stages are built: update BattleScene or StageSelect to be able to
load all three stages. Run each one, screenshot each, verify platforms look
correct. Commit before stopping.
```

---

## PHASE 10 — Menu Flow
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else. Focus on the Scene
Architecture section and the Menu UI Design section.

Phases 1–9 are complete. All 9 characters, all 3 stages, HUD, VFX, and audio
are working. BattleScene runs a full match with stock tracking and match end.

Invoke the game-development skill, then begin Phase 10 (Menu Flow).

Asset for all menus: assets/ui/menus/fantasy_ui.png — this sprite sheet
contains panel frames (teal, peach, dark red), buttons, and controller icons.
Slice it as needed using AtlasTexture regions. Use alagard.ttf for titles and
Planes_ValMore.ttf for body text.

Build these scenes in order, taking a screenshot after each:

1. scenes/ui/MainMenu.tscn:
   - Full screen background (use Windrise background or solid color)
   - Game title using alagard.ttf, large
   - Three buttons: START, OPTIONS, QUIT
   - Button style from fantasy_ui.png panel/button pieces
   - START → goes to CharacterSelect
   - QUIT → get_tree().quit()
   - Play menu_open SFX on scene load, confirm/back SFX on button press

2. scenes/ui/CharacterSelect.tscn:
   - Two panels side by side (Player 1 left, Player 2 right)
   - Each panel: 3×3 grid of character portraits (use idle frame 0 from each
     character's sprite sheet as portrait)
   - Cursor highlights selected character, moves with that player's input
   - Preview: show idle animation of highlighted character below the grid
   - Both players press confirm to lock in and advance to StageSelect
   - Show controller button prompts from fantasy_ui.png icons

3. scenes/ui/StageSelect.tscn:
   - Three stage cards showing stage name and background thumbnail
   - Player 1 selects with their input, Player 2can see but not override
   - RANDOM option shuffles selection
   - Confirm → load BattleScene with selected stage and characters stored
     in GameManager

4. scenes/ui/WinScreen.tscn:
   - "PLAYER [X] WINS" text in alagard.ttf
   - Winner's character plays their idle animation, large, centered
   - Two buttons: REMATCH (reload BattleScene with same characters/stage)
     and MENU (return to MainMenu)

5. Wire full scene flow via GameManager:
   - App starts → MainMenu
   - MainMenu START → CharacterSelect
   - CharacterSelect confirm → StageSelect
   - StageSelect confirm → BattleScene
   - BattleScene match_ended → WinScreen
   - WinScreen REMATCH → BattleScene
   - WinScreen MENU → MainMenu

After wiring: run through the complete flow start to finish. Screenshot each
screen. Verify transitions work, character select correctly passes selections
to GameManager, stage loads correctly, win screen shows right winner. Commit.
```

---

## PHASE 11 — Polish
*(Fresh session after /clear)*

```
Read CLAUDE.md in full before doing anything else.

Phases 1–10 are complete. Full game loop works: menus → character select →
stage select → battle → win screen → loop. All 9 characters, all 3 stages.

Invoke the game-development skill, then begin Phase 11 (Polish).

Work through each item, run the project and verify after each group:

GROUP A — Combat feel:
1. Screen shake on heavy hit: Camera2D with a Tween that offsets position by
   Vector2(8, 6) then returns to zero over 0.2 seconds
2. Hit pause already implemented (0.1s time scale) — verify it still feels
   correct with all character types
3. Hitstun visual: flash the struck character's sprite white for 3 frames
   on any hit (modulate Color(2, 2, 2) then restore)

GROUP B — Respawn and match flow:
4. Respawn animation: character fades in from above — spawn 150px above spawn
   point, tween position down over 0.5 seconds, fade alpha from 0 to 1
5. Match countdown: "3... 2... 1... FIGHT!" label overlay at battle start,
   characters cannot move until FIGHT appears. Use alagard.ttf.
6. Match end: brief slowdown (Engine.time_scale = 0.3) for 0.5 seconds before
   loading WinScreen

GROUP C — Options and settings:
7. Options menu accessible from MainMenu: three volume sliders (Music, SFX,
   Ambience) that call AudioManager.set_volume(). Settings persist using
   ConfigFile saved to user://settings.cfg and loaded on game start.

GROUP D — Final verification:
8. Play through a full match on each of the 3 stages with at least 2 different
   character matchups. Screenshot each stage in play.
9. Verify controller detection: confirm Input.get_connected_joypads() is called
   on BattleScene load, and that controller input works for both players
10. Check all 3 stages load without errors, music plays correctly per stage,
    ambience runs under music
11. Verify win condition is correct — match ends when stocks hit 0, not before

Take a final screenshot of each stage in active combat. Commit. The game is done.
```
